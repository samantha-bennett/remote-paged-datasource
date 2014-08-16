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
