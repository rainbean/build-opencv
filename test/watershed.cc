#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>
#include <iostream>
#include <chrono>
#include <string>
#include <thread>
#include <random>
#include <vector>
#include <numeric>
#include <algorithm>
#include <cmath>

using namespace std;
using namespace cv;

#define duration(t) std::chrono::duration_cast<std::chrono::milliseconds>(t).count()
#define timeNow() std::chrono::steady_clock::now()

// measure elapsed time routine
struct TimeIt {
    int &ms;
    const std::string msg;
    const std::chrono::steady_clock::time_point tp;

    TimeIt(int &ms, const std::string &msg) : ms(ms), msg(msg), tp(timeNow()) {}
    ~TimeIt() {
        ms += duration(timeNow() - tp);
        if (!msg.empty()) {
            std::cerr << "[TIME]\t" << ms << " ms - " << msg << std::endl;
        }
    }
};

struct ProcessResult {
    vector<int> bbox_areas; // bounding rect area per contour (width*height, integer pixels)
    int watershed_ms = 0;
};

ProcessResult process(const Mat &src) {
    ProcessResult result;

    // deep copy so parallel tasks don't share mutable state
    Mat img = src.clone();

    // Change the background from white to black
    Mat mask;
    inRange(img, Scalar(255, 255, 255), Scalar(255, 255, 255), mask);
    img.setTo(Scalar(0, 0, 0), mask);

    // Laplacian sharpening
    Mat kernel = (Mat_<float>(3,3) <<
                1,  1, 1,
                1, -8, 1,
                1,  1, 1);
    Mat imgLaplacian;
    filter2D(img, imgLaplacian, CV_32F, kernel);
    Mat sharp;
    img.convertTo(sharp, CV_32F);
    Mat imgResult = sharp - imgLaplacian;
    imgResult.convertTo(imgResult, CV_8UC3);
    imgLaplacian.convertTo(imgLaplacian, CV_8UC3);

    // Binary threshold via Otsu
    Mat bw;
    cvtColor(imgResult, bw, COLOR_BGR2GRAY);
    threshold(bw, bw, 40, 255, THRESH_BINARY | THRESH_OTSU);

    // Distance transform → peaks → markers
    Mat dist;
    distanceTransform(bw, dist, DIST_L2, 3);
    normalize(dist, dist, 0, 1.0, NORM_MINMAX);
    threshold(dist, dist, 0.4, 1.0, THRESH_BINARY);
    Mat kernel1 = Mat::ones(3, 3, CV_8U);
    dilate(dist, dist, kernel1);

    Mat dist_8u;
    dist.convertTo(dist_8u, CV_8U);
    vector<vector<Point>> contours;
    findContours(dist_8u, contours, RETR_EXTERNAL, CHAIN_APPROX_SIMPLE);
    assert(contours.size() == 14);

    // Capture bounding rect area for each contour
    for (const auto &c : contours) {
        result.bbox_areas.push_back(boundingRect(c).area());
    }

    // Build watershed markers
    Mat markers = Mat::zeros(dist.size(), CV_32S);
    for (size_t i = 0; i < contours.size(); i++) {
        drawContours(markers, contours, static_cast<int>(i), Scalar(static_cast<int>(i)+1), -1);
    }
    circle(markers, Point(5,5), 3, Scalar(255), -1);

    // Time the watershed call
    auto ws_start = timeNow();
    watershed(imgResult, markers);
    result.watershed_ms = duration(timeNow() - ws_start);

    Mat mark;
    markers.convertTo(mark, CV_8U);
    bitwise_not(mark, mark);

    // Generate random colors and render result
    vector<Vec3b> colors;
    for (size_t i = 0; i < contours.size(); i++) {
        int b = theRNG().uniform(0, 256);
        int g = theRNG().uniform(0, 256);
        int r = theRNG().uniform(0, 256);
        colors.push_back(Vec3b((uchar)b, (uchar)g, (uchar)r));
    }
    Mat dst = Mat::zeros(markers.size(), CV_8UC3);
    for (int i = 0; i < markers.rows; i++) {
        for (int j = 0; j < markers.cols; j++) {
            int index = markers.at<int>(i,j);
            if (index > 0 && index <= static_cast<int>(contours.size())) {
                dst.at<Vec3b>(i,j) = colors[index-1];
            }
        }
    }

    return result;
}

static void validate(const ProcessResult &r, const ProcessResult &ref, int iter) {
    assert(r.bbox_areas.size() == ref.bbox_areas.size());
    for (size_t j = 0; j < r.bbox_areas.size(); j++) {
        double delta = std::fabs(r.bbox_areas[j] - ref.bbox_areas[j]) / (double)ref.bbox_areas[j];
        if (delta > 0.02) {
            std::cerr << "[FAIL]\titer=" << iter << " contour=" << j
                      << " area=" << r.bbox_areas[j] << " ref=" << ref.bbox_areas[j]
                      << " delta=" << delta * 100.0 << "%" << std::endl;
            assert(false);
        }
    }
}

void delay() {
    std::this_thread::sleep_for(std::chrono::milliseconds{10});
}

int main(int argc, char *argv[])
{
    CommandLineParser parser( argc, argv, "{@input | cards.png | input image}" );
    Mat src = imread( samples::findFile( parser.get<String>( "@input" ) ) );
    if( src.empty() )
    {
        cout << "Could not open or find the image!\n" << endl;
        cout << "Usage: " << argv[0] << " <Input image>" << endl;
        return -1;
    }

    // Establish reference from a single baseline run
    ProcessResult ref = process(src);
    std::cerr << "[REF]\tcontours=" << ref.bbox_areas.size()
              << " watershed=" << ref.watershed_ms << "ms" << std::endl;
    std::cerr << "[REF]\tbbox_areas:";
    for (int a : ref.bbox_areas) std::cerr << " " << a;
    std::cerr << std::endl;

    // 100-iteration benchmark loop
    vector<ProcessResult> results(100);
    auto loop_start = timeNow();

#pragma omp parallel
{
    #pragma omp single
        for (size_t i = 0; i < 100; i++)
        {
            delay(); // simulate partial code requiring single thread
    #pragma omp task shared(src, results) firstprivate(i)
            results[i] = process(src);
        }
}

    auto loop_ms = duration(timeNow() - loop_start);

    // Validate all results against reference
    for (size_t i = 0; i < results.size(); i++) {
        validate(results[i], ref, i);
    }

    // Timing summary
    vector<int> ws_times;
    for (const auto &r : results) ws_times.push_back(r.watershed_ms);
    int ws_total = std::accumulate(ws_times.begin(), ws_times.end(), 0);
    int ws_min = *std::min_element(ws_times.begin(), ws_times.end());
    int ws_max = *std::max_element(ws_times.begin(), ws_times.end());

    std::cerr << "[BENCH]\twatershed: avg=" << ws_total / 100
              << "ms min=" << ws_min << "ms max=" << ws_max << "ms" << std::endl;
    std::cerr << "[BENCH]\ttotal loop: " << loop_ms << "ms (100 iterations)" << std::endl;

    return 0;
}
