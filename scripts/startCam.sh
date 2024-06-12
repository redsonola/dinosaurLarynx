#! /bin/sh

gst-launch-1.0 libcamerasrc ! "video/x-raw,width=1280,height=1080,format=YUY2",interlace-mode=progressive ! videoconvert ! v4l2sink device=/dev/video8
