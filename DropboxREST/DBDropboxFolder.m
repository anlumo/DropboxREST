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

#import "DBDropboxFolder.h"
#import "DBDropboxClient.h"

@implementation DBDropboxFolder {
	NSDictionary *cached_metadata;
}

- (void)getMetadataWithCompletionHandler:(void(^)(NSDictionary *metadata, NSError *error))completionHandler {
	[self.client fetchMetadataForPath:self.path revision:nil hash:[cached_metadata objectForKey:@"hash"] completionHandler:^(NSDictionary *metadata, NSError *error) {
		if(error)
			completionHandler(nil, error);
		else {
			if(metadata)
				cached_metadata = metadata;
			completionHandler(cached_metadata, nil);
		}
	}];
}

- (void)getFilesWithCompletionHandler:(void(^)(NSSet *files, NSError *error))completionHandler {
	[self getMetadataWithCompletionHandler:^(NSDictionary *metadata, NSError *error) {
		if(error)
			completionHandler(nil, error);
		else {
			NSMutableSet *set = [NSMutableSet set];
			for(NSDictionary *file in [metadata objectForKey:@"contents"]) {
				NSString *path = [[file objectForKey:@"path"] DB_removeSlash];
				NSString *rev = [file objectForKey:@"rev"];
				NSString *isdir = [file objectForKey:@"is_dir"];
				
				if(!path)
					continue; // shouldn't happen
				
				if([isdir boolValue]) {
					DBDropboxFolder *subfolder = [[DBDropboxFolder alloc] initWithPath:path revision:rev client:self.client];
					[set addObject:subfolder];
					[subfolder release];
				} else {
					DBDropboxFile *subfile = [[DBDropboxFile alloc] initWithPath:path revision:rev client:self.client];
					[set addObject:subfile];
					[subfile release];
				}
			}
			completionHandler(set, nil);
		}
	}];
}

- (void)copyToPath:(NSString*)newPath completionHandler:(void(^)(DBDropboxFile *file, NSError *error))completionHandler {
	[self.client copyItemAtPath:self.path toPath:[newPath DB_removeSlash] completionHandler:^(NSDictionary *metadata, NSError *error) {
		if(error)
			completionHandler(nil, error);
		else
			completionHandler([[[DBDropboxFolder alloc] initWithPath:[[metadata objectForKey:@"path"] DB_removeSlash] revision:[metadata objectForKey:@"rev"] client:self.client] autorelease], nil);
	}];
}

- (void)createSubfolderWithName:(NSString*)name completionHandler:(void(^)(DBDropboxFolder *folder, NSError *error))completionHandler {
	[self.client createFolderAtPath:[self.path stringByAppendingPathComponent:name] completionHandler:^(NSDictionary *metadata, NSError *error) {
		if(error)
			completionHandler(nil, error);
		else
			completionHandler([[[DBDropboxFolder alloc] initWithPath:[[metadata objectForKey:@"path"] DB_removeSlash] revision:[metadata objectForKey:@"rev"] client:self.client] autorelease], nil);
	}];
}

- (void)createFileWithName:(NSString*)name contents:(NSData*)contents completionHandler:(void(^)(DBDropboxFile *file, NSError *error))completionHandler {
	[self.client uploadData:contents toFile:[self.path stringByAppendingPathComponent:name] withParentRevision:nil overwrite:YES completionHandler:^(NSDictionary *metadata, NSError *error) {
		if(error)
			completionHandler(nil, error);
		else
			completionHandler([[[DBDropboxFile alloc] initWithPath:[[metadata objectForKey:@"path"] DB_removeSlash] revision:[metadata objectForKey:@"rev"] client:self.client] autorelease], nil);
	}];
}

@end
