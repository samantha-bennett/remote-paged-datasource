//
//  TCArrayDataSource.m
//  GroupRecommendations
//
//  Created by Thomas Bennett on 6/27/14.
//  Copyright (c) 2014 Technicolor. All rights reserved.
//

#import "RemotePagedDataSource.h"

@interface RemotePagedDataSource()

@property (nonatomic, weak, readonly) UITableView *tableView;
@property (nonatomic, copy, readonly) NSString *cellIdentifier;
@property (nonatomic, strong, readonly) TableViewCellConfigureBlock configureCellBlock;

@property (nonatomic, assign, readonly) int resultsPerPage;
@property (nonatomic, assign, readonly) int pagesToPrefetchOnEachSide;
@property (nonatomic, weak, readonly) id<RemotePagedDataSourceDelegate> delegate;
@property (nonatomic, strong, readonly) NSURLSession *session;

@property (nonatomic, copy) NSMutableDictionary *pages;
@property (nonatomic, copy) NSMutableSet *pagesCurrentlyBeingFetched;

// Allow monitoring of scrolling speed.
@property (nonatomic, assign) CGPoint lastOffset;
@property (nonatomic, assign) NSTimeInterval lastOffsetCapture;
@end

@implementation RemotePagedDataSource

/** Although no REST calls are made while scrolling faster than the threshold, there is no throttling of REST requests based on scroll behavior.
    That is, there is no upper bound on the number of concurrent or continuous REST requests, nor are requests cancelled at any point. 
    If such functionality is required, it should be handled as part of the RESTBlock.
 **/
- (instancetype)initWithTableView:(UITableView *)tableView
                   cellIdentifier:(NSString *)cellIdentifier
                   resultsPerPage:(int)resultsPerPage
        pagesToPrefetchOnEachSide:(int)pagesToPrefetchOnEachSide
                         delegate:(id<RemotePagedDataSourceDelegate>)delegate
               configureCellBlock:(TableViewCellConfigureBlock)configureCellBlock {
    self = [super init];
    if (self) {
        _tableView = tableView;
        _cellIdentifier = cellIdentifier;
        _delegate = delegate;
        _configureCellBlock = configureCellBlock;
        _pagesToPrefetchOnEachSide = pagesToPrefetchOnEachSide;
        _resultsPerPage = resultsPerPage;
        
        _pages = [[NSMutableDictionary alloc] init];
        _pagesCurrentlyBeingFetched = [[NSMutableSet alloc] init];
        
        _totalPages = 0;
        _totalResults = 0;
        
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        [config setHTTPAdditionalHeaders:@{@"Accept": @"application/json"}];
        _session = [NSURLSession sessionWithConfiguration:config];
        
        [self startRESTTaskForPage:1];
    }
    return self;
}

- (void)dealloc {
    _configureCellBlock = nil;
}

- (int)pageForIndexPath:(NSIndexPath *)indexPath {
    return (int)(indexPath.row / self.resultsPerPage) + 1;
}

- (int)rowOffsetForIndexPath:(NSIndexPath *)indexPath {
    return indexPath.row % self.resultsPerPage;
}

- (id)itemAtIndexPath:(NSIndexPath*)indexPath {
    int pageNumber = [self pageForIndexPath:indexPath];
    int cellNumber = [self rowOffsetForIndexPath:indexPath];
    
    NSArray *resultsForPage = [self.pages objectForKey:[NSNumber numberWithInt:pageNumber]];
    
    id item = nil;
    if ([resultsForPage count] > cellNumber) {
        // TODO: Update page calculation with this. Need to note the delta and page it occurs on.
        item = resultsForPage[cellNumber];
    }
    
    return item;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.totalResults;
}

- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath {
    id cell = [tableView dequeueReusableCellWithIdentifier:self.cellIdentifier forIndexPath:indexPath];
    id item = [self itemAtIndexPath:indexPath];
    self.configureCellBlock(cell,item);
    return cell;
}

- (void)clearData {
    [self.pages removeAllObjects];
    [self.pagesCurrentlyBeingFetched removeAllObjects];
}

// TODO: Figure out a better way to do this.
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGPoint currentOffset = self.tableView.contentOffset;
    NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];
    
    NSTimeInterval timeDiff = currentTime - self.lastOffsetCapture;
    if(timeDiff > 0.1) {
        CGFloat distance = currentOffset.y - self.lastOffset.y;
        //The multiply by 10, / 1000 isn't really necessary.......
        CGFloat scrollSpeedNotAbs = (distance * 10) / 1000; //in pixels per millisecond
        
        CGFloat scrollSpeed = fabsf(scrollSpeedNotAbs);
        if (scrollSpeed < 0.5) {
            NSIndexPath *indexPath = [[self.tableView indexPathsForVisibleRows] lastObject];
            int page = [self pageForIndexPath:indexPath];
            [self makeRESTCallForPage:page withAdjacentPages:self.pagesToPrefetchOnEachSide];
        }
        
        self.lastOffset = currentOffset;
        self.lastOffsetCapture = currentTime;
    }
}

- (void)addData:(NSArray *)data forPage:(int)page {    
    NSNumber *nsPage = [NSNumber numberWithInt:page];
    [self.pages setObject:data forKey:nsPage];
    [self.pagesCurrentlyBeingFetched removeObject:nsPage];
    [self.tableView performSelectorOnMainThread:@selector(reloadData)
                                     withObject:nil
                                  waitUntilDone:false];
}

- (void)makeRESTCallForPage:(int)pageIndex {
    NSNumber *nsPage = [NSNumber numberWithInt:pageIndex];
    if (!([self.pagesCurrentlyBeingFetched containsObject:nsPage] || [self.pages objectForKey:nsPage])) {
        [self.pagesCurrentlyBeingFetched addObject:nsPage];
        [self startRESTTaskForPage:pageIndex];
    }
}

- (void)makeRESTCallForPage:(int)page withAdjacentPages:(int)numberAdjacent {
    [self makeRESTCallForPage:page];
    
    // Request surrounding pages.
    for (int pageIndex = MAX(1, page - numberAdjacent); pageIndex <= page + numberAdjacent; pageIndex++) {
        [self makeRESTCallForPage:pageIndex];
    }
}

- (void)startRESTTaskForPage:(int)pageIndex {
    static const UInt16 kMaxRecommendationRequests = 10;
    static NSMutableArray *requestQueue = nil;
    if (!requestQueue) {
        requestQueue = [[NSMutableArray alloc] init];
    } else if ([requestQueue count] >= kMaxRecommendationRequests) {
        NSURLSessionDataTask *dataTask = [requestQueue firstObject];
        [requestQueue removeObject:dataTask];
        [dataTask cancel];
    }
    
    NSURL *url = [self.delegate urlForPageIndex:pageIndex];
    NSURLSessionDataTask *dataTask =
    [self.session dataTaskWithURL:url
            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                [self.delegate processResultsForPage:pageIndex withURL:url responseData:data urlResponse:response error:error];
            }];
    
    [requestQueue addObject:dataTask];
    
    [dataTask resume];
};
@end
