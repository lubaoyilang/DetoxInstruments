//
//  DTXCPUDataProvider.m
//  DetoxInstruments
//
//  Created by Leo Natan (Wix) on 12/06/2017.
//  Copyright © 2017 Wix. All rights reserved.
//

#import "DTXCPUDataProvider.h"
#import "DTXCPUInspectorDataProvider.h"
#import "DTXThreadInfo+UIExtensions.h"

@implementation DTXCPUDataProvider

+ (Class)inspectorDataProviderClass
{
	return [DTXCPUInspectorDataProvider class];
}

- (NSArray<DTXColumnInformation *> *)columns
{
	NSMutableArray<DTXColumnInformation*>* rv = [NSMutableArray new];
	
	DTXColumnInformation* info = [DTXColumnInformation new];
	info.title = self.titleOfCPUHeader;
	info.minWidth = 70;
	
	[rv addObject:info];
	
	if(self.showsHeaviestThreadColumn)
   {
	   DTXColumnInformation* heaviestThread = [DTXColumnInformation new];
	   heaviestThread.title = NSLocalizedString(@"Heaviest Thread", @"");
	   heaviestThread.minWidth = 300;
	   heaviestThread.automaticallyGrowsWithTable = YES;
	   
	   [rv addObject:heaviestThread];
   }
	else
	{
		info.automaticallyGrowsWithTable = YES;
	}
	
	return rv;
}

- (NSArray<NSNumber *> *)sampleTypes
{
	return @[@(DTXSampleTypePerformance), @(DTXSampleTypeAdvancedPerformance)];
}

- (NSString*)formattedStringValueForItem:(id)item column:(NSUInteger)column;
{
	if(column == 0)
	{
		return [[NSFormatter dtx_percentFormatter] stringForObjectValue:@([(DTXPerformanceSample*)item cpuUsage])];
	}
	
	DTXAdvancedPerformanceSample* advPerf = item;
	
	__block DTXThreadInfo* heaviestThread = nil;
	__block double heaviestCPU = -1;
	
	[advPerf.threadSamples enumerateObjectsUsingBlock:^(DTXThreadPerformanceSample * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
		if(obj.cpuUsage > heaviestCPU)
		{
			heaviestThread = obj.threadInfo;
			heaviestCPU = obj.cpuUsage;
		}
	}];
	
	if(heaviestThread == nil)
	{
		return @"<?>";
	}
	
	return heaviestThread.friendlyName;
}

- (NSColor*)textColorForItem:(id)item
{
	return NSColor.labelColor;
}

- (NSColor*)backgroundRowColorForItem:(id)item
{
	double cpu = [(DTXPerformanceSample*)item cpuUsage];
	double fps = [(DTXPerformanceSample*)item fps];
	
	if([item isKindOfClass:[DTXAdvancedPerformanceSample class]] && [item threadSamples].count > 0)
	{
		DTXAdvancedPerformanceSample* advanced = item;
		
		if(advanced.threadSamples.firstObject.cpuUsage > 0.9)
		{
			return NSColor.warning3Color;
		}
		else if(advanced.threadSamples.firstObject.cpuUsage > 0.8)
		{
			return NSColor.warning2Color;
		}
		else if(advanced.threadSamples.firstObject.cpuUsage > 0.7)
		{
			return NSColor.warningColor;
		}
		
		cpu = cpu - advanced.threadSamples.firstObject.cpuUsage;
	}
	else
	{
		if(fps <= 30 && cpu >= 0.95)
		{
			return NSColor.warning3Color;
		}
	}
	
	return cpu >= 2.0 ? NSColor.warning3Color : cpu > 1.5 ? NSColor.warning2Color : cpu > 1.0 ? NSColor.warningColor : NSColor.controlBackgroundColor;
}

- (NSString*)statusTooltipforItem:(id)item
{
	double cpu = [(DTXPerformanceSample*)item cpuUsage];
	double fps = [(DTXPerformanceSample*)item fps];
	
	if([item isKindOfClass:[DTXAdvancedPerformanceSample class]] && [item threadSamples].count > 0)
	{
		DTXAdvancedPerformanceSample* advanced = item;
		
		if(advanced.threadSamples.firstObject.cpuUsage > 0.9)
		{
			return NSLocalizedString(@"Main thread usage above 90%", @"");
		}
		else if(advanced.threadSamples.firstObject.cpuUsage > 0.8)
		{
			return NSLocalizedString(@"Main thread usage above 80%", @"");
		}
		else if(advanced.threadSamples.firstObject.cpuUsage > 0.7)
		{
			return NSLocalizedString(@"Main thread usage above 70%", @"");
		}
		
		cpu = cpu - advanced.threadSamples.firstObject.cpuUsage;
	}
	else
	{
		if(fps < 30 && cpu >= 0.95)
		{
			return NSLocalizedString(@"CPU usage above 95% and FPS lower than 30", @"");
		}
	}
	
	return cpu >= 2.0 ? NSLocalizedString(@"CPU usage above 200%", @"") : cpu > 1.5 ? NSLocalizedString(@"CPU usage above 150%", @"") : cpu > 1.0 ? NSLocalizedString(@"CPU usage above 100%", @"") : nil;
}

- (NSString*)titleOfCPUHeader
{
	return NSLocalizedString(@"CPU Usage", @"");
}

- (BOOL)showsHeaviestThreadColumn
{
	return YES;
}

@end
