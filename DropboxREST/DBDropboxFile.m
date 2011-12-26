/*
 Copyright 2011 Andreas Monitzer. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice,
 this list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY ANDREAS MONITZER ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL ANDREAS MONITZER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import "DBDropboxFile.h"
#import "DBDropboxClient.h"

@implementation NSString (noslash)

- (NSString*)DB_removeSlash {
	if([self hasPrefix:@"/"])
		return [self substringFromIndex:1];
	else
		return self;
}

@end

@interface DBDropboxFile ()
@property (copy) NSString *path;
@property (copy) NSString *revision;
@end

@implementation DBDropboxFile
@synthesize path, client, revision;

+ (NSSet*)keyPathsForValuesAffectingName {
	return [NSSet setWithObject:@"path"];
}

- (NSString*)name {
	return [self.path lastPathComponent];
}

- (id)initWithPath:(NSString*)path_ revision:(NSString*)revision_ client:(DBDropboxClient*)client_ {
	if((self = [super init])) {
		path = [path_ copy];
		client = [client_ retain];
		revision = [revision_ copy];
	}
	return self;
}

- (void)dealloc {
	[path release];
	[revision release];
	[client release];
	[super dealloc];
}

- (void)setPath:(NSString*)newPath completionHandler:(void(^)(NSError *error))completionHandler {
	[client moveItemAtPath:self.path toPath:[newPath DB_removeSlash] completionHandler:^(NSDictionary *metadata, NSError *error) {
		if(error)
			completionHandler(error);
		else {
			self.path = [[metadata objectForKey:@"path"] DB_removeSlash];
			completionHandler(nil);
		}
	}];
}

- (void)getMetadataWithCompletionHandler:(void(^)(NSDictionary*, NSError*))completionHandler {
	[client fetchMetadataForPath:self.path revision:self.revision hash:nil completionHandler:completionHandler];
}

- (void)copyToPath:(NSString*)newPath completionHandler:(void(^)(DBDropboxFile *file, NSError *error))completionHandler {
	[client copyItemAtPath:self.path toPath:[newPath DB_removeSlash] completionHandler:^(NSDictionary *metadata, NSError *error) {
		if(error)
			completionHandler(nil, error);
		else
			completionHandler([[[DBDropboxFile alloc] initWithPath:[[metadata objectForKey:@"path"] DB_removeSlash] revision:[metadata objectForKey:@"rev"] client:client] autorelease], nil);
	}];
}

- (void)getContentsWithCompletionHandler:(void(^)(NSData *contents, NSError *error))completionHandler {
	[client getFileAtPath:self.path revision:self.revision completionHandler:completionHandler];
}

- (void)deleteWithCompletionHandler:(void(^)(NSError *error))completionHandler {
	[client deletePath:self.path completionHandler:^(NSDictionary *metadata, NSError *error) {
		completionHandler(error);
	}];
}

- (void)shareWithCompletionHandler:(void(^)(NSURL *url, NSError *error))completionHandler {
	[client shareFileAtPath:self.path completionHandler:^(NSDictionary *info, NSError *error) {
		if(error)
			completionHandler(nil, error);
		else if([info objectForKey:@"url"])
			completionHandler([NSURL URLWithString:[info objectForKey:@"url"]], nil);
		else
			completionHandler(nil, nil); // shouldn't happen
	}];
}

- (void)setContents:(NSData*)contents completionHandler:(void(^)(NSError *error))completionHandler {
	[client uploadData:contents toFile:self.path withParentRevision:self.revision overwrite:YES completionHandler:^(NSDictionary *metadata, NSError *error) {
		if(error)
			completionHandler(error);
		else {
			/* If parent_rev matches the latest version of the file on the user's Dropbox, that file will be replaced. Otherwise, the new file will be automatically renamed (for example, test.txt might be automatically renamed to test (conflicted copy).txt). */
			if(![self.path isEqualToString:[[metadata objectForKey:@"path"] DB_removeSlash]]) {
				self.path = [[metadata objectForKey:@"path"] DB_removeSlash];
			}
			
			[self willChangeValueForKey:@"revision"];
			revision = [metadata objectForKey:@"rev"];
			[self didChangeValueForKey:@"revision"];
			completionHandler(nil);
		}
	}];
}

- (NSString*)description {
	return [NSString stringWithFormat:@"<%@ '%@'>", self.className, self.path];
}

@end
