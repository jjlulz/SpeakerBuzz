
TARGET := iphone:clang:latest:12.0
ARCHS := arm64

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME := SpeakerBuzz

SpeakerBuzz_FILES := Sources/main.m
SpeakerBuzz_FRAMEWORKS := UIKit AVFoundation AudioToolbox
SpeakerBuzz_CFLAGS := -fobjc-arc
SpeakerBuzz_BUNDLE_ID := com.speakerbuzz.app
SpeakerBuzz_INSTALL_PATH := /Applications

include $(THEOS_MAKE_PATH)/application.mk
