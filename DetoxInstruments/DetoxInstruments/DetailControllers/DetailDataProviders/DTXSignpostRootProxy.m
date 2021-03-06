//
//  DTXSignpostRootProxy.m
//  DetoxInstruments
//
//  Created by Leo Natan (Wix) on 7/1/18.
//  Copyright © 2018 Wix. All rights reserved.
//

#import "DTXSignpostRootProxy.h"
#import "DTXSignpostCategoryProxy.h"
#import "DTXSignpostSample+UIExtensions.h"

@implementation DTXSignpostRootProxy

- (instancetype)initWithManagedObjectContext:(NSManagedObjectContext*)managedObjectContext outlineView:(NSOutlineView*)outlineView
{
	self = [super initWithKeyPath:@"category" isRoot:YES managedObjectContext:managedObjectContext outlineView:outlineView];
	
	if(self)
	{
	}
	
	return self;
}

- (Class)sampleClass
{
	return DTXSignpostSample.class;
}

- (id)objectForSample:(id)sample
{
	return [[DTXSignpostCategoryProxy alloc] initWithCategory:sample managedObjectContext:self.managedObjectContext outlineView:self.outlineView];
}

@end
