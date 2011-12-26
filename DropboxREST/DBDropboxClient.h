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

#import "AFHTTPClient.h"

@class DBDropboxFolder;

@interface DBDropboxClient : AFHTTPClient
@property (copy) void(^authenticationCallback)(NSString *oauth_token, void(^completionHandler)(NSError *error));
+ (void)setConsumerKey:(NSString*)key andSecret:(NSString*)secret;
+ (DBDropboxClient*)client;

- (void)fetchUserInfoWithCompletionHandler:(void(^)(NSDictionary *info, NSError *error))completionHandler;

- (DBDropboxFolder*)rootFolder;

#pragma mark - Low Level Routines

- (void)fetchMetadataForPath:(NSString*)path revision:(NSString*)rev hash:(NSString*)hash completionHandler:(void(^)(NSDictionary *metadata, NSError *error))completionHandler;
- (void)uploadData:(NSData*)data toFile:(NSString*)fullPath withParentRevision:(NSString*)parent_rev overwrite:(BOOL)overwrite completionHandler:(void(^)(NSDictionary *metadata,NSError *error))completionHandler;

- (void)getFileAtPath:(NSString*)fullpath revision:(NSString*)rev completionHandler:(void(^)(NSData *content, NSError *error))completionHandler;
- (void)shareFileAtPath:(NSString*)fullpath completionHandler:(void(^)(NSDictionary *info, NSError *error))completionHandler;

// File operations

- (void)deletePath:(NSString*)fullPath completionHandler:(void(^)(NSDictionary *metadata,NSError *error))completionHandler;
- (void)createFolderAtPath:(NSString*)fullPath completionHandler:(void(^)(NSDictionary *metadata,NSError *error))completionHandler;
- (void)copyItemAtPath:(NSString*)from_fullPath toPath:(NSString*)to_fullPath completionHandler:(void(^)(NSDictionary *metadata,NSError *error))completionHandler;
- (void)moveItemAtPath:(NSString*)from_fullPath toPath:(NSString*)to_fullPath completionHandler:(void(^)(NSDictionary *metadata,NSError *error))completionHandler;
@end
