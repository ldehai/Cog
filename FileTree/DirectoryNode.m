//
//  DirectoryNode.m
//  Cog
//
//  Created by Vincent Spader on 8/20/2006.
//  Copyright 2006 Vincent Spader. All rights reserved.
//

#import "DirectoryNode.h"

#import "FileNode.h"
#import "SmartFolderNode.h"

#import "NSString+FinderCompare.h"

@implementation DirectoryNode

- (BOOL)isLeaf {
	return NO;
}

- (void)updatePath {
	if(!url) return;

	// Pre-fetch all needed resource keys so the enumerator caches them (avoids per-file stat/I/O)
	NSArray *resourceKeys = @[NSURLNameKey, NSURLIsDirectoryKey, NSURLIsAliasFileKey, NSURLLocalizedNameKey];
	NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:url
	                                                         includingPropertiesForKeys:resourceKeys
	                                                                            options:(NSDirectoryEnumerationSkipsSubdirectoryDescendants | NSDirectoryEnumerationSkipsPackageDescendants | NSDirectoryEnumerationSkipsHiddenFiles)
	                                                                       errorHandler:^BOOL(NSURL *url, NSError *error) {
		                                                                       return NO;
	                                                                       }];
	NSMutableArray<NSURL *> *urls = [NSMutableArray new];

	for(NSURL *theUrl in enumerator) {
		[urls addObject:theUrl];
	}

	[urls sortUsingComparator:^NSComparisonResult(NSURL *a, NSURL *b) {
		return [[a path] finderCompare:[b path]];
	}];

	[self processURLs:urls];
}

@end
