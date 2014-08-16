//
//  TCArrayDataSource.h
//  GroupRecommendations
//
//  Created by Thomas Bennett on 6/27/14.
//  Copyright (c) 2014 Technicolor. All rights reserved.
//

@import Foundation;

// Update the given cell using the given item.
typedef void (^TableViewCellConfigureBlock)(id cell, id item);

@protocol RemotePagedDataSourceDelegate <NSObject>

// Construct the NSURL to make the REST request for the given page.
- (NSURL *)urlForPageIndex:(int) page;
// Interpret the results from the REST call made using the URL obtained from ConstructURLForPageIndex.
- (void) processResultsForPage:(int)pageIndex withURL:(NSURL *)url responseData:(NSData *)data urlResponse:(NSURLResponse *)urlResponse error:(NSError *)error;

@end


@interface RemotePagedDataSource : NSObject <UITableViewDataSource>

@property (nonatomic, assign) NSInteger totalResults;
@property (nonatomic, assign) NSInteger totalPages;

- (instancetype)initWithTableView:(UITableView *)tableView
                   cellIdentifier:(NSString *)cellIdentifier
                   resultsPerPage:(int)resultsPerPage
        pagesToPrefetchOnEachSide:(int)pagesToPrefetchOnEachSide
                         delegate:(id<RemotePagedDataSourceDelegate>)delegate
               configureCellBlock:(TableViewCellConfigureBlock)configureCellBlock;

- (id)itemAtIndexPath:(NSIndexPath *)indexPath;

- (void)scrollViewDidScroll:(UIScrollView *)scrollView;
- (void)addData:(NSArray *)data forPage:(int)page;
- (void)clearData;
@end
