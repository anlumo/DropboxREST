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

#import <Foundation/Foundation.h>

@class DBDropboxClient;

@interface DBDropboxFile : NSObject
@property (copy, readonly) NSString *path;
@property (readonly) NSString *name;
@property (copy, readonly) NSString *revision;
@property (readonly) DBDropboxClient *client;

- (id)initWithPath:(NSString*)path_ revision:(NSString*)revision_ client:(DBDropboxClient*)client_;

- (void)setPath:(NSString*)newPath completionHandler:(void(^)(NSError *error))completionHandler;
- (void)getMetadataWithCompletionHandler:(void(^)(NSDictionary *metadata, NSError *error))completionHandler;
- (void)copyToPath:(NSString*)newPath completionHandler:(void(^)(DBDropboxFile *file, NSError *error))completionHandler;

- (void)deleteWithCompletionHandler:(void(^)(NSError *error))completionHandler;
- (void)shareWithCompletionHandler:(void(^)(NSURL *url, NSError *error))completionHandler;

- (void)getContentsWithCompletionHandler:(void(^)(NSData *contents, NSError *error))completionHandler;
- (void)setContents:(NSData*)contents completionHandler:(void(^)(NSError *error))completionHandler;

@end

@interface NSString (noslash)
- (NSString*)DB_removeSlash;
@end
