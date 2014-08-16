Based on the idea set out in [Lighter View Controllers](http://www.objc.io/issue-1/lighter-view-controllers.html), but extended to handle data backed by a service. 

Instead of pausing at the end of a "page" in the scroll view, this code will prefetch content in the background. The effect is an "infinite scroll" based on the number of results returned in the JSON response.

Example on how to use:
    // Setup the data source.
    void (^configureCell)(UITableViewCell*, id*) = ^(UITableViewCell *cell, id *data) {
		// Update cell with data.
    };


    self.mediaArrayDataSource = [[TCRemotePagedDataSource alloc] initWithTableView:self.tableView
                                                                    cellIdentifier:CellIdentifier
                                                                    resultsPerPage:20
                                                         pagesToPrefetchOnEachSide:4
                                                                          delegate:self
                                                                configureCellBlock:configureCell];
    self.tableView.dataSource = self.mediaArrayDataSource;
	
	
	
The delegate you pass must implement the RemotePagedDataSourceDelegate protocol:

	- (NSURL *)urlForPageIndex:(int) page;
Construct and return the NSURL to make the REST request for the given page index

	- (void) processResultsForPage:(int)pageIndex withURL:(NSURL *)url responseData:(NSData *)data urlResponse:(NSURLResponse *)urlResponse error:(NSError *)error;
Interpret the results from the REST call made using the URL obtained from ConstructURLForPageIndex.
