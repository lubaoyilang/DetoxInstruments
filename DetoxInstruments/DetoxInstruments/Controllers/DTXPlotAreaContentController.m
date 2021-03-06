//
//  DTXPlotAreaContentController.m
//  DetoxInstruments
//
//  Created by Leo Natan (Wix) on 01/06/2017.
//  Copyright © 2017 Wix. All rights reserved.
//

#import "DTXPlotAreaContentController.h"
#import "DTXPlotTableView.h"
#import "DTXManagedPlotControllerGroup.h"
#import "DTXAxisHeaderPlotController.h"
#import "DTXCPUUsagePlotController.h"
#import "DTXThreadCPUUsagePlotController.h"
#import "DTXMemoryUsagePlotController.h"
#import "DTXFPSPlotController.h"
#import "DTXDiskReadWritesPlotController.h"
#import "DTXCompactNetworkRequestsPlotController.h"
#import "DTXRNCPUUsagePlotController.h"
#import "DTXRNBridgeCountersPlotController.h"
#import "DTXRNBridgeDataTransferPlotController.h"
#import "DTXEventsPlotController.h"
#import "DTXRecording+UIExtensions.h"
#import "DTXSignpostSample+UIExtensions.h"
#import "DTXNetworkSample+UIExtensions.h"
#import "DTXPlotControllerPickerController.h"
#import "DTXClassSelectionButton.h"
#import "DTXScrollView.h"

#import "DTXLayerView.h"

@interface DTXPlotAreaContentController () <DTXManagedPlotControllerGroupDelegate, NSFetchedResultsControllerDelegate, NSTouchBarDelegate>
{
	IBOutlet DTXPlotTableView* _tableView;
	DTXManagedPlotControllerGroup* _plotGroup;
	IBOutlet NSView* _headerView;
	
	DTXCPUUsagePlotController* _cpuPlotController;
	NSMutableArray<DTXThreadInfo*>* _insertedCPUThreads;
	NSFetchedResultsController* _threadsObserver;
	
	Class _touchBarPlotControllerClass;
	__weak id<DTXPlotController> _selectedPlotController;
	id<DTXPlotController> _touchBarPlotController;
}

@end

@implementation DTXPlotAreaContentController

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	_tableView.enclosingScrollView.contentInsets = NSEdgeInsetsMake(0, 0, 20, 0);
	_tableView.enclosingScrollView.scrollerInsets = NSEdgeInsetsMake(0, 210.5, -20, 0);
	
	[(DTXScrollView*)_tableView.enclosingScrollView setHorizontalScrollerKnobProportion:1.0 value:0.0];
	
	_tableView.enclosingScrollView.autohidesScrollers = NO;
	((DTXScrollView*)_tableView.enclosingScrollView).customHorizontalScroller.target = self;
	((DTXScrollView*)_tableView.enclosingScrollView).customHorizontalScroller.action = @selector(_horizontalScrollerDidScroll:);
}

- (void)_horizontalScrollerDidScroll:(NSScroller*)sender
{
	[_plotGroup scrollToValue:sender.doubleValue];
}

- (void)viewWillAppear
{
	[super viewWillAppear];
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[self.document readyForRecordingIfNeeded];
	});
	
	[_tableView.window makeFirstResponder:_tableView];
}

- (void)setDocument:(DTXRecordingDocument *)document
{
	if(_document)
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:DTXRecordingDocumentStateDidChangeNotification object:_document];
	}
	
	_document = document;
	
	[self _reloadPlotGroupIfNeeded];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_documentStateDidChangeNotification:) name:DTXRecordingDocumentStateDidChangeNotification object:_document];
}

- (void)_documentStateDidChangeNotification:(NSNotification*)note
{
	_plotGroup = nil;
	
	if(self.document.recordings.count == 0)
	{
		return;
	}
	
	[self _reloadPlotGroupIfNeeded];
}

- (void)_reloadPlotGroupIfNeeded
{
	_headerView.hidden = self.document.documentState == DTXRecordingDocumentStateNew;
	
	if(self.document.documentState == DTXRecordingDocumentStateNew)
	{
		return;
	}
	
	if(_plotGroup)
	{
		return;
	}
	
	_plotGroup = [[DTXManagedPlotControllerGroup alloc] initWithHostingOutlineView:_tableView document:_document];
	_plotGroup.delegate = self;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_documentDefactoEndTimestampDidChange:) name:DTXRecordingDocumentDefactoEndTimestampDidChangeNotification object:self.document];
	
	if(self.document.documentState < DTXRecordingDocumentStateLiveRecordingFinished)
	{
		[_plotGroup setGlobalStartTimestamp:self.document.firstRecording.defactoStartTimestamp endTimestamp:[NSDate distantFuture]];
		[_plotGroup setLocalStartTimestamp:self.document.firstRecording.defactoStartTimestamp endTimestamp:[self.document.firstRecording.defactoStartTimestamp dateByAddingTimeInterval:120]];
	}
	else
	{
		[_plotGroup setGlobalStartTimestamp:self.document.firstRecording.defactoStartTimestamp endTimestamp:self.document.lastRecording.defactoEndTimestamp];
		[_plotGroup setLocalStartTimestamp:self.document.firstRecording.defactoStartTimestamp endTimestamp:self.document.lastRecording.defactoEndTimestamp];
	}
	
	_tableView.intercellSpacing = NSMakeSize(1, 0);
	
	DTXAxisHeaderPlotController* headerPlotController = [[DTXAxisHeaderPlotController alloc] initWithDocument:self.document];
	[headerPlotController setUpWithView:_headerView insets:NSEdgeInsetsMake(0, 209.5, 0, 0) isForTouchBar:NO];

	[_plotGroup setHeaderPlotController:headerPlotController];

	_cpuPlotController = [[DTXCPUUsagePlotController alloc] initWithDocument:self.document];
	[_plotGroup addPlotController:_cpuPlotController];

	NSFetchRequest* fr = [DTXThreadInfo fetchRequest];
	fr.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"recording.startTimestamp" ascending:YES], [NSSortDescriptor sortDescriptorWithKey:@"number" ascending:YES]];

	_threadsObserver = [[NSFetchedResultsController alloc] initWithFetchRequest:fr managedObjectContext:self.document.firstRecording.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
	_threadsObserver.delegate = self;
	[_threadsObserver performFetch:nil];

	NSArray* threads = _threadsObserver.fetchedObjects;
	if(threads.count > 0)
	{
		[threads enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
			[_plotGroup addChildPlotController:[[DTXThreadCPUUsagePlotController alloc] initWithDocument:self.document threadInfo:obj] toPlotController:_cpuPlotController];
		}];
	}

	[_plotGroup addPlotController:[[DTXMemoryUsagePlotController alloc] initWithDocument:self.document]];
	[_plotGroup addPlotController:[[DTXFPSPlotController alloc] initWithDocument:self.document]];
	[_plotGroup addPlotController:[[DTXDiskReadWritesPlotController alloc] initWithDocument:self.document]];
	
	[_plotGroup addPlotController:[[DTXCompactNetworkRequestsPlotController alloc] initWithDocument:self.document]];
	[_plotGroup addPlotController:[[DTXEventsPlotController alloc] initWithDocument:self.document]];
	
	if(self.document.firstRecording.hasReactNative && self.document.firstRecording.dtx_profilingConfiguration.profileReactNative)
	{
		[_plotGroup addPlotController:[[DTXRNCPUUsagePlotController alloc] initWithDocument:self.document]];
		[_plotGroup addPlotController:[[DTXRNBridgeCountersPlotController alloc] initWithDocument:self.document]];
		[_plotGroup addPlotController:[[DTXRNBridgeDataTransferPlotController alloc] initWithDocument:self.document]];
	}
	
	//This fixes an issue where the main content table does not size correctly.
	NSRect rect = self.view.window.frame;
	rect.size.width += 1;
	[self.view.window setFrame:rect display:YES];
	rect.size.width -= 1;
	[self.view.window setFrame:rect display:YES];
}

- (void)zoomIn
{
	[_plotGroup zoomIn];
}

- (void)zoomOut
{
	[_plotGroup zoomOut];
}

- (void)fitAllData
{
	[_plotGroup zoomToFitAllData];
}

- (void)_documentDefactoEndTimestampDidChange:(NSNotification*)note
{
	if(self.document.documentState < DTXRecordingDocumentStateLiveRecordingFinished)
	{
		return;
	}
	
	[_plotGroup setGlobalStartTimestamp:[note.object recording].defactoStartTimestamp endTimestamp:[note.object recording].defactoEndTimestamp];
	[_plotGroup setLocalStartTimestamp:[note.object recording].defactoStartTimestamp endTimestamp:[note.object recording].defactoEndTimestamp];
}

- (void)presentPlotControllerPickerFromView:(NSView*)view
{
	DTXPlotControllerPickerController* plotControllerPicker = [self.storyboard instantiateControllerWithIdentifier:@"DTXPlotControllerPickerController"];
	plotControllerPicker.managedPlotControllerGroup = _plotGroup;
	
	if([self.presentedViewControllers.firstObject isKindOfClass:DTXPlotControllerPickerController.class])
	{
		[self dismissViewController:self.presentedViewControllers.firstObject];
		return;
	}
	[self presentViewController:plotControllerPicker asPopoverRelativeToRect:view.bounds ofView:view preferredEdge:NSRectEdgeMaxY behavior:NSPopoverBehaviorSemitransient];
}

#pragma mark DTXManagedPlotControllerGroupDelegate

- (void)managedPlotControllerGroup:(DTXManagedPlotControllerGroup*)group didScrollToProportion:(CGFloat)proportion value:(CGFloat)value
{
	[(DTXScrollView*)_tableView.enclosingScrollView setHorizontalScrollerKnobProportion:proportion value:value];
}

- (void)managedPlotControllerGroup:(DTXManagedPlotControllerGroup *)group didSelectPlotController:(id<DTXPlotController>)plotController
{
	[self.delegate contentController:self updatePlotController:plotController];
	
	_selectedPlotController = plotController;
	_touchBarPlotController.sampleClickDelegate = plotController.sampleClickDelegate;
}

- (void)managedPlotControllerGroup:(DTXManagedPlotControllerGroup*)group didHidePlotController:(id<DTXPlotController>)plotController
{
	if(_touchBarPlotControllerClass == plotController.class)
	{
		_touchBarPlotControllerClass = nil;
		_touchBarPlotController = nil;
	}
	
	[self.delegate reloadTouchBar];
}

- (void)managedPlotControllerGroup:(DTXManagedPlotControllerGroup*)group didShowPlotController:(id<DTXPlotController>)plotController
{
	[self.delegate reloadTouchBar];
}

#pragma mark NSFetchedResultsControllerDelegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
	_insertedCPUThreads = [NSMutableArray new];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(nullable NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(nullable NSIndexPath *)newIndexPath
{
	if(type == NSFetchedResultsChangeInsert)
	{
		[_insertedCPUThreads addObject:anObject];
	}
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
	[_insertedCPUThreads sortUsingDescriptors:controller.fetchRequest.sortDescriptors];
	
	[_insertedCPUThreads enumerateObjectsUsingBlock:^(DTXThreadInfo * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
		[_plotGroup addChildPlotController:[[DTXThreadCPUUsagePlotController alloc] initWithDocument:self.document threadInfo:obj] toPlotController:_cpuPlotController];
	}];
}

#pragma mark NSTouchBarDelegate

- (void)_handleTouchBarSelection:(DTXClassSelectionButton*)button
{
	_touchBarPlotControllerClass = button.selectionClass;
	_touchBarPlotController = nil;
	
	[self.delegate reloadTouchBar];
}

- (nullable NSTouchBarItem *)touchBar:(NSTouchBar *)touchBar makeItemForIdentifier:(NSTouchBarItemIdentifier)identifier
{
	if(_touchBarPlotController == nil)
	{
		if(_touchBarPlotControllerClass == nil)
		{
			_touchBarPlotControllerClass = _plotGroup.visiblePlotControllers.firstObject.class;
		}
		
		NSUInteger idx = [_plotGroup.visiblePlotControllers indexOfObjectPassingTest:^BOOL(id<DTXPlotController>  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
			if([obj isKindOfClass:_touchBarPlotControllerClass.class])
			{
				return YES;
			}
			
			return NO;
		}];
		
		id<DTXPlotController> plotController = _plotGroup.visiblePlotControllers[idx];
		
		_touchBarPlotController = [[_touchBarPlotControllerClass alloc] initWithDocument:self.document];
		[_touchBarPlotController requiredHeight];
		_touchBarPlotController.parentPlotController = plotController;
		_touchBarPlotController.sampleClickDelegate = _selectedPlotController.sampleClickDelegate;
		
		[_plotGroup setTouchBarPlotController:_touchBarPlotController];
	}
	
	if ([identifier isEqualToString:@"TouchBarPlotController"])
	{
		DTXLayerView* customView = [DTXLayerView new];
		customView.allowedTouchTypes = NSTouchTypeMaskDirect;
		
		[_touchBarPlotController setUpWithView:customView insets:NSEdgeInsetsZero isForTouchBar:YES];
		
		NSClickGestureRecognizer* clickGestureRecognizer = [[NSClickGestureRecognizer alloc] initWithTarget:_touchBarPlotController action:@selector(clickedByClickGestureRegonizer:)];
		clickGestureRecognizer.allowedTouchTypes = NSTouchTypeMaskDirect;
		[customView addGestureRecognizer:clickGestureRecognizer];
		
		auto item = [[NSCustomTouchBarItem alloc] initWithIdentifier:@"TouchBarPlotController"];
		item.view = customView;
		
		return item;
	}
	else if ([identifier isEqualToString:@"TouchBarPlotControllerSelector"])
	{
		NSScrollView* scrollView = [NSScrollView new];
		
		NSMutableDictionary *constraintViews = [NSMutableDictionary dictionary];
		NSView *documentView = [[NSView alloc] initWithFrame:NSZeroRect];
		documentView.translatesAutoresizingMaskIntoConstraints = NO;
		
		NSString *layoutFormat = @"H:|";
		NSSize size = NSMakeSize(8, 30);
		
		for (id<DTXPlotController> plotController in _plotGroup.visiblePlotControllers)
		{
			auto button = [DTXClassSelectionButton buttonWithTitle:plotController.displayName target:self action:@selector(_handleTouchBarSelection:)];
			button.selectionClass = plotController.class;
			button.image = plotController.smallDisplayIcon;
			button.imagePosition = NSImageLeading;
			button.imageHugsTitle = YES;
			button.translatesAutoresizingMaskIntoConstraints = NO;
			[button setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
			[button setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
			[documentView addSubview:button];
			
			NSString* ptr = NSStringFromClass(plotController.class);
			
			// Constraint information
			layoutFormat = [layoutFormat stringByAppendingString:[NSString stringWithFormat:@"[%@]-8-", ptr]];
			[constraintViews setObject:button forKey:ptr];
		}
		
		layoutFormat = [layoutFormat stringByAppendingString:[NSString stringWithFormat:@"|"]];
		
		NSArray *hConstraints = [NSLayoutConstraint constraintsWithVisualFormat:layoutFormat
																		options:NSLayoutFormatAlignAllCenterY
																		metrics:nil
																		  views:constraintViews];
		
		[documentView setFrame:NSMakeRect(0, 0, size.width, size.height)];
		[NSLayoutConstraint activateConstraints:hConstraints];
		scrollView.documentView = documentView;
		
		auto scrubberItem = [[NSCustomTouchBarItem alloc] initWithIdentifier:@"TouchBarPlotControllerSelectorGroup"];
		scrubberItem.view = scrollView;
		
		auto groupTouchBar = [NSTouchBar new];
		groupTouchBar.defaultItemIdentifiers = @[@"TouchBarPlotControllerSelectorGroup"];
		groupTouchBar.templateItems = [NSSet setWithObject:scrubberItem];
		
		auto item = [[NSPopoverTouchBarItem alloc] initWithIdentifier:@"TouchBarPlotControllerSelector"];
		item.collapsedRepresentationImage = [_touchBarPlotController smallDisplayIcon];
//		item.collapsedRepresentationLabel = [_touchBarPlotController displayName];
		item.popoverTouchBar = groupTouchBar;
		
		return item;
	}
	
	return nil;
}

@end

