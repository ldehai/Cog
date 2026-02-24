//
//  Node.m
//  Cog
//
//  Created by Vincent Spader on 8/20/2006.
//  Copyright 2006 Vincent Spader. All rights reserved.
//

#import "PathNode.h"

#import "CogAudio/AudioPlayer.h"

#import "FileTreeDataSource.h"

#import "ContainerNode.h"
#import "DirectoryNode.h"
#import "FileNode.h"
#import "SmartFolderNode.h"

#import "Logging.h"

@implementation PathNode

// From http://developer.apple.com/documentation/Cocoa/Conceptual/LowLevelFileMgmt/Tasks/ResolvingAliases.html
// Updated 2018-06-28
NSURL *resolveAliases(NSURL *url) {
	CFErrorRef error;
	CFDataRef bookmarkRef = CFURLCreateBookmarkDataFromFile(kCFAllocatorDefault, (__bridge CFURLRef)url, &error);
	if(bookmarkRef) {
		Boolean isStale;
		CFURLRef urlRef = CFURLCreateByResolvingBookmarkData(kCFAllocatorDefault, bookmarkRef, kCFURLBookmarkResolutionWithSecurityScope, NULL, NULL, &isStale, &error);
		CFRelease(bookmarkRef);

		if(urlRef) {
			if(!isStale) {
				return (NSURL *)CFBridgingRelease(urlRef);
			} else {
				CFRelease(urlRef);
			}
		}
	}

	// DLog(@"Not resolved");
	return url;
}

- (id)initWithDataSource:(FileTreeDataSource *)ds url:(NSURL *)u {
	self = [super init];

	if(self) {
		dataSource = ds;
		[self setURL:u];
	}

	return self;
}

- (void)setURL:(NSURL *)u {
	url = u;

	lastPathComponent = [[u path] lastPathComponent];

	// Reset lazy-loaded properties
	display = nil;
	icon = nil;
	iconLoaded = NO;
}

- (NSURL *)URL {
	return url;
}

- (void)updatePath {
}

// Cache supported file types as NSSet for O(1) lookups instead of O(n) NSArray scans
static NSSet *sCachedFileTypes = nil;
static NSSet *sCachedContainerTypes = nil;
static dispatch_once_t sFileTypesOnceToken;

static void ensureFileTypeCaches(void) {
	dispatch_once(&sFileTypesOnceToken, ^{
		sCachedFileTypes = [NSSet setWithArray:[AudioPlayer fileTypes]];
		sCachedContainerTypes = [NSSet setWithArray:[AudioPlayer containerTypes]];
	});
}

- (void)processPaths:(NSArray *)contents {
	NSMutableArray *newSubpathsDirs = [NSMutableArray new];
	NSMutableArray *newSubpaths = [NSMutableArray new];

	ensureFileTypeCaches();

	for(NSString *s in contents) {
		if([s characterAtIndex:0] == '.') {
			continue;
		}

		NSURL *u = [NSURL fileURLWithPath:s];
		NSString *displayName = [[NSFileManager defaultManager] displayNameAtPath:[u path]];

		PathNode *newNode;

		// Only resolve aliases if the file is actually an alias (avoids expensive bookmark API calls)
		NSNumber *isAliasValue = nil;
		[u getResourceValue:&isAliasValue forKey:NSURLIsAliasFileKey error:nil];
		if([isAliasValue boolValue]) {
			u = resolveAliases(u);
		}

		BOOL isDir;

		if([[s pathExtension] caseInsensitiveCompare:@"savedSearch"] == NSOrderedSame) {
			DLog(@"Smart folder!");
			newNode = [[SmartFolderNode alloc] initWithDataSource:dataSource url:u];
			isDir = NO;
		} else {
			[[NSFileManager defaultManager] fileExistsAtPath:[u path] isDirectory:&isDir];

			if(!isDir && ![sCachedFileTypes containsObject:[[u pathExtension] lowercaseString]]) {
				continue;
			}

			if(isDir) {
				newNode = [[DirectoryNode alloc] initWithDataSource:dataSource url:u];
			} else if([sCachedContainerTypes containsObject:[[u pathExtension] lowercaseString]]) {
				newNode = [[ContainerNode alloc] initWithDataSource:dataSource url:u];
			} else {
				newNode = [[FileNode alloc] initWithDataSource:dataSource url:u];
			}
		}

		[newNode setDisplay:displayName];

		if(isDir)
			[newSubpathsDirs addObject:newNode];
		else
			[newSubpaths addObject:newNode];
	}

	[newSubpathsDirs addObjectsFromArray:newSubpaths];
	[self setSubpaths:newSubpathsDirs];
}

- (void)processURLs:(NSArray<NSURL *> *)urls {
	NSMutableArray *newSubpathsDirs = [NSMutableArray new];
	NSMutableArray *newSubpaths = [NSMutableArray new];

	ensureFileTypeCaches();

	for(NSURL *u in urls) {
		NSString *name = nil;
		[u getResourceValue:&name forKey:NSURLNameKey error:nil];
		if([name length] > 0 && [name characterAtIndex:0] == '.') continue;

		// Use pre-fetched localized name from directory enumerator (no extra disk I/O)
		NSString *displayName = nil;
		[u getResourceValue:&displayName forKey:NSURLLocalizedNameKey error:nil];
		if(!displayName) displayName = name;

		// Only resolve aliases if the file is actually an alias
		NSNumber *isAliasValue = nil;
		[u getResourceValue:&isAliasValue forKey:NSURLIsAliasFileKey error:nil];
		NSURL *resolvedURL = u;
		if([isAliasValue boolValue]) {
			resolvedURL = resolveAliases(u);
		}

		PathNode *newNode;
		BOOL isDir;

		NSString *ext = [[u pathExtension] lowercaseString];
		if([ext isEqualToString:@"savedsearch"]) {
			DLog(@"Smart folder!");
			newNode = [[SmartFolderNode alloc] initWithDataSource:dataSource url:resolvedURL];
			isDir = NO;
		} else {
			// Use pre-fetched directory flag (no extra stat() call for non-alias files)
			if(resolvedURL == u) {
				NSNumber *isDirValue = nil;
				[u getResourceValue:&isDirValue forKey:NSURLIsDirectoryKey error:nil];
				isDir = [isDirValue boolValue];
			} else {
				// Alias was resolved to a different URL; need fresh stat
				[[NSFileManager defaultManager] fileExistsAtPath:[resolvedURL path] isDirectory:&isDir];
			}

			if(!isDir && ![sCachedFileTypes containsObject:ext]) {
				continue;
			}

			if(isDir) {
				newNode = [[DirectoryNode alloc] initWithDataSource:dataSource url:resolvedURL];
			} else if([sCachedContainerTypes containsObject:ext]) {
				newNode = [[ContainerNode alloc] initWithDataSource:dataSource url:resolvedURL];
			} else {
				newNode = [[FileNode alloc] initWithDataSource:dataSource url:resolvedURL];
			}
		}

		[newNode setDisplay:displayName];

		if(isDir)
			[newSubpathsDirs addObject:newNode];
		else
			[newSubpaths addObject:newNode];
	}

	[newSubpathsDirs addObjectsFromArray:newSubpaths];
	[self setSubpaths:newSubpathsDirs];
}

- (NSArray *)subpaths {
	if(subpaths == nil) {
		[self updatePath];
	}

	return subpaths;
}

- (void)setSubpaths:(NSArray *)s {
	subpaths = s;

	subpathsLookup = [NSMutableDictionary new];
	for(PathNode *node in s) {
		[subpathsLookup setObject:node forKey:node.lastPathComponent];
	}
}

- (NSDictionary *)subpathsLookup {
	return subpathsLookup;
}

- (void)setSubpathsLookup:(NSMutableDictionary *)d {
	subpathsLookup = d;
}

- (BOOL)isLeaf {
	return YES;
}

- (void)setDisplay:(NSString *)s {
	display = s;
}

- (NSString *)display {
	if(!display && url) {
		display = [[NSFileManager defaultManager] displayNameAtPath:[url path]];
	}
	return display;
}

- (NSImage *)icon {
	if(!iconLoaded) {
		icon = [[NSWorkspace sharedWorkspace] iconForFile:[url path]];
		[icon setSize:NSMakeSize(16.0, 16.0)];
		iconLoaded = YES;
	}
	return icon;
}

- (NSString *)lastPathComponent {
	return lastPathComponent;
}

- (void)setLastPathComponent:(NSString *)s {
	lastPathComponent = s;
}

@end
