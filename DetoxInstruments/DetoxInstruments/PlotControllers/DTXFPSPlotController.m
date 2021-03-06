//
//  DTXFPSPlotController.m
//  DetoxInstruments
//
//  Created by Leo Natan (Wix) on 04/06/2017.
//  Copyright © 2017 Wix. All rights reserved.
//

#import "DTXFPSPlotController.h"
#import "DTXFPSDataProvider.h"

@implementation DTXFPSPlotController

+ (Class)UIDataProviderClass
{
	return [DTXFPSDataProvider class];
}

- (NSString *)displayName
{
	return NSLocalizedString(@"FPS", @"");
}

- (NSString *)toolTip
{
	return NSLocalizedString(@"The FPS instrument captures information about the frame-rate of the profiled app's user interface.", @"");
}

- (NSImage*)displayIcon
{
	return [NSImage imageNamed:@"GPU"];
}

- (NSArray<NSString*>*)sampleKeys
{
	return @[@"fps"];
}

- (NSArray<NSString*>*)plotTitles
{
	return @[NSLocalizedString(@"FPS", @"")];
}

- (NSArray<NSColor*>*)plotColors
{
	return @[NSColor.fpsPlotControllerColor];
}

- (id)transformedValueForFormatter:(id)value
{
	double fps = [value doubleValue];
	if(fps >= 56)
	{
		return @(60);
	}
	
	return @(fps);
}

@end
