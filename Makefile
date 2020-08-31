# This Makefile is used for CI builds and tests.

BUILD_DIR := build

DERIVED_DATA_DIR := $(BUILD_DIR)/derived_data
RESULTS_DIR := $(BUILD_DIR)/results

CONFIGURATION := Debug
XCODE_BUILD_OPTIONS := -configuration $(CONFIGURATION) 

XCODE_BUILD_SETTINGS := ONLY_ACTIVE_ARCH=NO
ifdef LTO
  XCODE_BUILD_SETTINGS += LLVM_LTO=$(LTO)
endif

ASAN := YES

SKIP_SLOW_TESTS := true

IOS11_VERSION := 11.4

XCPRETTY_PATH := $(shell command -v xcpretty 2> /dev/null)
XCPRETTY := 
ifdef XCPRETTY_PATH
  XCPRETTY := | xcpretty -c
  ifeq ($(TRAVIS),true)
    XCPRETTY += -f `xcpretty-travis-formatter`
  endif
endif

XCODEBUILD := set -o pipefail && $(shell command -v xcodebuild) \
              -derivedDataPath $(DERIVED_DATA_DIR) \
              $(XCODE_BUILD_OPTIONS)

RESULTBUNDLEPATH = -resultBundlePath $(BUILD_DIR)/results/$@_$(shell date +%Y-%m-%d_%H_%M_%S)

                    # The order determines the order in the HTML report.
TEST_RESULT_PATHS = $(wildcard $(BUILD_DIR)/results/test-ios12*) \
                    $(wildcard $(BUILD_DIR)/results/test-ios11*) \
                    $(wildcard $(BUILD_DIR)/results/test-ios10*) \
                    $(wildcard $(BUILD_DIR)/results/test-ios9*)

XCODEBUILD_STATIC_FOR_TEST = $(XCODEBUILD) $(RESULTBUNDLEPATH) -scheme "STULabel static" \
                             -enableAddressSanitizer $(ASAN)

SKIP_TESTING := 
ifeq ($(SKIP_SLOW_TESTS),true)
  SKIP_TESTING := -skip-testing:AllTests/NSStringRefTests/testGraphemeClusterBreakFinding \
                  -skip-testing:AllTests/ShapedStringTests/testCTTypesetterThreadSafety
endif

XCODEBUILD_TEST_WITHOUT_BUILDING = \
  $(XCODEBUILD_STATIC_FOR_TEST) -destination $($@_DESTINATION) \
    test-without-building $(SKIP_TESTING) $(XCPRETTY)

XCODEBUILD_TEST_ALL_WITHOUT_BUILDING = \
  $(XCODEBUILD_STATIC_FOR_TEST) -destination $($@_DESTINATION) \
    test-without-building $(XCPRETTY)

build: build-for-testing build-demo

build-for-testing:
	$(XCODEBUILD_STATIC_FOR_TEST) -destination 'generic/platform=iOS Simulator' \
    build-for-testing $(XCODE_BUILD_SETTINGS) $(XCPRETTY)

build-demo:
	$(XCODEBUILD) $(RESULTBUNDLEPATH) -scheme "Demo" -destination 'generic/platform=iOS' \
    build $(XCODE_BUILD_SETTINGS) $(XCPRETTY)

clean:
	$(XCODEBUILD) -scheme "STULabel static" clean $(XCPRETTY)
	$(XCODEBUILD) -scheme "Demo" clean $(XCPRETTY)

test: test-ios12 test-ios11 test-ios10 test-ios9
test-ios12: test-ios12-ipad-pro-11 test-ios12-iphone-xs-max
test-ios11: test-ios11-ipad-pro-10_5 test-ios11-iphone-x
test-ios10: test-ios10-ipad-pro-9_7 test-ios10-iphone-7-plus
test-ios9: test-ios9-iphone-6s test-ios9-iphone-6s-plus test-ios9-ipad-2

generate-test-report:
	mkdir -p $(BUILD_DIR)/results/html-test-report
	xchtmlreport -j $(foreach dir,$(TEST_RESULT_PATHS),-r $(dir))
	cp $(firstword $(TEST_RESULT_PATHS))/*.{html,txt} $(BUILD_DIR)/results/html-test-report/
	rm $(firstword $(TEST_RESULT_PATHS))/*.{html,txt}
	cp $(firstword $(TEST_RESULT_PATHS))/report.junit $(BUILD_DIR)/results/test-results.xml
	rm $(firstword $(TEST_RESULT_PATHS))/report.junit

test-ios12-ipad-pro-11_DESTINATION := 'platform=iOS Simulator,OS=latest,name=iPad Pro (11-inch)'
test-ios12-ipad-pro-11:
	$(XCODEBUILD_TEST_ALL_WITHOUT_BUILDING)

test-ios12-iphone-xs-max_DESTINATION := 'platform=iOS Simulator,OS=latest,name=iPhone Xs Max'
test-ios12-iphone-xs-max: 
	$(XCODEBUILD_TEST_WITHOUT_BUILDING)

test-ios11-ipad-pro-10_5_DESTINATION := 'platform=iOS Simulator,OS=$(IOS11_VERSION),name=iPad Pro (10.5-inch)'
test-ios11-ipad-pro-10_5:
	$(XCODEBUILD_TEST_WITHOUT_BUILDING)

test-ios11-iphone-x_DESTINATION := 'platform=iOS Simulator,OS=$(IOS11_VERSION),name=iPhone X'
test-ios11-iphone-x: 
	$(XCODEBUILD_TEST_WITHOUT_BUILDING)

test-ios10-ipad-pro-9_7_DESTINATION := 'platform=iOS Simulator,OS=10.3.1,name=iPad Pro (9.7-inch)'
test-ios10-ipad-pro-9_7:
	$(XCODEBUILD_TEST_WITHOUT_BUILDING)

test-ios10-iphone-7-plus_DESTINATION := 'platform=iOS Simulator,OS=10.3.1,name=iPhone 7 Plus'
test-ios10-iphone-7-plus: 
	$(XCODEBUILD_TEST_WITHOUT_BUILDING)

test-ios9-iphone-6s_DESTINATION := 'platform=iOS Simulator,OS=9.3,name=iPhone 6s'
test-ios9-iphone-6s: 
	$(XCODEBUILD_TEST_WITHOUT_BUILDING)

test-ios9-iphone-6s-plus_DESTINATION := 'platform=iOS Simulator,OS=9.3,name=iPhone 6s Plus'
test-ios9-iphone-6s-plus: 
	$(XCODEBUILD_TEST_WITHOUT_BUILDING)

test-ios9-ipad-2_DESTINATION := 'platform=iOS Simulator,OS=9.3,name=iPad 2'
test-ios9-ipad-2:
	$(XCODEBUILD_TEST_WITHOUT_BUILDING)

ROOT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

clean:
	rm -rf build

xcframework: clean
	xcodebuild -project "STULabel.xcodeproj" -sdk iphonesimulator VALID_ARCHS=x86_64 -arch x86_64 -configuration Release -target STULabel BUILD_LIBRARY_FOR_DISTRIBUTION=YES
	xcodebuild -project "STULabel.xcodeproj" -sdk iphoneos -arch arm64 -configuration Release -target STULabel BUILD_LIBRARY_FOR_DISTRIBUTION=YES
	xcodebuild -create-xcframework \
	-framework "build/Release-iphoneos/STULabel.framework" \
	-framework "build/Release-iphonesimulator/STULabel.framework" \
	-output "build/STULabel.xcframework"
	xcodebuild -project "STULabel.xcodeproj" -sdk iphonesimulator VALID_ARCHS=x86_64 -arch x86_64 -configuration Release -target STULabelSwift BUILD_LIBRARY_FOR_DISTRIBUTION=YES
	xcodebuild -project "STULabel.xcodeproj" -sdk iphoneos -arch arm64 -configuration Release -target STULabelSwift BUILD_LIBRARY_FOR_DISTRIBUTION=YES
	xcodebuild -create-xcframework \
	-framework "build/Release-iphoneos/STULabelSwift.framework" \
	-framework "build/Release-iphonesimulator/STULabelSwift.framework" \
	-output "build/STULabelSwift.xcframework"