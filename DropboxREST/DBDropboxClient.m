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

#import "DBDropboxClient.h"
#import "GCOAuth.h"
#import "AFJSONRequestOperation.h"
#import "DBDropboxFolder.h"

static NSString *gConsumerKey;
static NSString *gConsumerSecret;

@interface DBDropboxClient ()
@property (copy) NSString *oauth_token_secret;
@property (copy) NSString *oauth_token;

- (void)requestTokenWithCompletionHandler:(void(^)(NSString *oauth_token,NSError *error))completionHandler;
- (void)fetchAccessTokenWithCompletionHandler:(void(^)(NSError *error))completionHandler;

- (void)checkAccessTokenWithCompletionHandler:(void(^)(NSError *error))completionHandler;
@end

@implementation DBDropboxClient
@synthesize useAppFolder, authenticationCallback, oauth_token, oauth_token_secret;

+ (void)setConsumerKey:(NSString*)key andSecret:(NSString*)secret {
	[gConsumerKey release];
	[gConsumerSecret release];
	gConsumerKey = [key copy];
	gConsumerSecret = [secret copy];
}

+ (DBDropboxClient*)client {
	return (DBDropboxClient*)[self clientWithBaseURL:[NSURL URLWithString:@"https://api.dropbox.com/1/"]];
}

- (id)initWithBaseURL:(NSURL *)url {
	if((self = [super initWithBaseURL:url])) {
		// register handlers here
		[self registerHTTPOperationClass:[AFJSONRequestOperation class]];
	}
	return self;
}

- (void)dealloc {
	[authenticationCallback release];
	[oauth_token release];
	[oauth_token_secret release];
	[super dealloc];
}

#pragma mark - Authentication

- (void)requestTokenWithCompletionHandler:(void(^)(NSString*,NSError*))completionHandler {
	NSURLRequest *requesttoken = [GCOAuth URLRequestForPath:@"/1/oauth/request_token"
											 POSTParameters:[NSDictionary dictionary]
													   host:@"api.dropbox.com"
												consumerKey:gConsumerKey
											 consumerSecret:gConsumerSecret
												accessToken:nil
												tokenSecret:nil];
	
	AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:requesttoken success:^(AFHTTPRequestOperation *operation, id responseObject) {
		NSString *response = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
		NSArray *fields = [response componentsSeparatedByString:@"&"];
		
		self.oauth_token_secret = nil;
		self.oauth_token = nil;
		for(NSString *field in fields) {
			NSArray *parts = [field componentsSeparatedByString:@"="];
			if([parts count] != 2)
				continue;
			if([[parts objectAtIndex:0] isEqualToString:@"oauth_token_secret"])
				self.oauth_token_secret = [[parts objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
			else if([[parts objectAtIndex:0] isEqualToString:@"oauth_token"])
				self.oauth_token = [[parts objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		}
		
		if(self.oauth_token_secret && self.oauth_token)
			completionHandler(self.oauth_token, nil);
		else
			completionHandler(nil, [NSError errorWithDomain:@"com.monitzer.DropboxREST" code:403 userInfo:nil]);
		[response release];
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		completionHandler(nil, error);
	}];
	
	[self enqueueHTTPRequestOperation:op];
}

- (void)fetchAccessTokenWithCompletionHandler:(void(^)(NSError *error))completionHandler {
	NSURLRequest *req = [GCOAuth URLRequestForPath:@"/1/oauth/access_token"
									POSTParameters:nil
											  host:@"api.dropbox.com"
									   consumerKey:gConsumerKey
									consumerSecret:gConsumerSecret
									   accessToken:self.oauth_token
									   tokenSecret:self.oauth_token_secret];
	AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:req success:^(AFHTTPRequestOperation *operation, id responseObject) {
		NSString *response = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
		NSArray *fields = [response componentsSeparatedByString:@"&"];
		
		self.oauth_token_secret = self.oauth_token = nil;
		for(NSString *field in fields) {
			NSArray *parts = [field componentsSeparatedByString:@"="];
			if([parts count] != 2)
				continue;
			if([[parts objectAtIndex:0] isEqualToString:@"oauth_token_secret"])
				self.oauth_token_secret = [[parts objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
			else if([[parts objectAtIndex:0] isEqualToString:@"oauth_token"])
				self.oauth_token = [[parts objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		}
		
		if(self.oauth_token && self.oauth_token_secret) {
			[[NSUserDefaults standardUserDefaults] setObject:self.oauth_token forKey:@"DBDropBoxAccessToken"];
			[[NSUserDefaults standardUserDefaults] setObject:self.oauth_token_secret forKey:@"DBDropBoxAccessTokenSecret"];
		}
		
		completionHandler(nil);
		[response release];
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		completionHandler(error);
	}];
	
	[self enqueueHTTPRequestOperation:op];
}

- (AFHTTPRequestOperation *)HTTPRequestOperationWithRequest:(NSURLRequest *)urlRequest 
                                                    success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
                                                    failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure {
	return [super HTTPRequestOperationWithRequest:urlRequest success:success failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if(operation.response.statusCode == 401) {
			[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DBDropBoxAccessToken"];
			[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DBDropBoxAccessTokenSecret"];
			failure(operation, [NSError errorWithDomain:@"com.monitzer.DropboxREST" code:401 userInfo:nil]);
		} else
			failure(operation, error);
	}];
}

- (void)checkAccessTokenWithCompletionHandler:(void(^)(NSError*))completionHandler {
	NSAssert(authenticationCallback != nil, @"DBDropboxClient: authenticationCallback must not be nil!");
	self.oauth_token = [[NSUserDefaults standardUserDefaults] objectForKey:@"DBDropBoxAccessToken"];
	self.oauth_token_secret = [[NSUserDefaults standardUserDefaults] objectForKey:@"DBDropBoxAccessTokenSecret"];

	if(self.oauth_token && self.oauth_token_secret) {
		completionHandler(nil);
		return;
	}
	
	[self requestTokenWithCompletionHandler:^(NSString *local_oauth_token, NSError *error) {
		if(error)
			completionHandler(error);
		else {
			authenticationCallback(local_oauth_token, ^(NSError *error) {
				if(error)
					completionHandler(error);
				else
					[self fetchAccessTokenWithCompletionHandler:completionHandler];
			});
		}
	}];
}

#pragma mark - API

- (void)fetchUserInfoWithCompletionHandler:(void(^)(NSDictionary *info, NSError *error))completionHandler {
	[self checkAccessTokenWithCompletionHandler:^(NSError *error) {
		if(error) {
			completionHandler(nil, error);
			return;
		}
		NSMutableURLRequest *req = [[GCOAuth URLRequestForPath:@"/1/account/info"
												 GETParameters:nil
														scheme:@"https"
														  host:@"api.dropbox.com"
												   consumerKey:gConsumerKey
												consumerSecret:gConsumerSecret
												   accessToken:self.oauth_token
												   tokenSecret:self.oauth_token_secret] mutableCopy];
		[req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
		AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:req success:^(AFHTTPRequestOperation *operation, id responseObject) {
			completionHandler(responseObject, nil);
		} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
			if([[error domain] isEqualToString:@"com.monitzer.DropboxREST"] && [error code] == 401)
				[self fetchUserInfoWithCompletionHandler:completionHandler]; // try again
			else
				completionHandler(nil, error);
		}];
		
		[self enqueueHTTPRequestOperation:op];
		[req release];
	}];
}

- (void)fetchMetadataForPath:(NSString*)path revision:(NSString*)rev hash:(NSString*)hash completionHandler:(void(^)(NSDictionary*,NSError*))completionHandler {
	[self checkAccessTokenWithCompletionHandler:^(NSError *error) {
		if(error) {
			completionHandler(nil, error);
			return;
		}
		NSMutableDictionary *params = [NSMutableDictionary dictionaryWithCapacity:2];
		if(rev)
			[params setObject:rev forKey:@"rev"];
		if(hash)
			[params setObject:hash forKey:@"hash"];
		NSMutableURLRequest *req = [[GCOAuth URLRequestForPath:path?[NSString stringWithFormat:@"/1/metadata/%@/%@", self.useAppFolder?@"sandbox":@"dropbox", path]:[@"/1/metadata/" stringByAppendingString:self.useAppFolder?@"sandbox":@"dropbox"]
												 GETParameters:params
														scheme:@"https"
														  host:@"api.dropbox.com"
												   consumerKey:gConsumerKey
												consumerSecret:gConsumerSecret
												   accessToken:self.oauth_token
												   tokenSecret:self.oauth_token_secret] mutableCopy];
		[req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
		AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:req success:^(AFHTTPRequestOperation *operation, id responseObject) {
			completionHandler(responseObject, nil);
		} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
			if([[error domain] isEqualToString:@"com.monitzer.DropboxREST"] && [error code] == 401)
				[self fetchMetadataForPath:path revision:rev hash:hash completionHandler:completionHandler]; // try again
			else if([error code] == 304) // not changed
				completionHandler(nil, nil);
			else
				completionHandler(nil, error);
		}];
		
		[self enqueueHTTPRequestOperation:op];
		[req release];
	}];
}

- (void)uploadData:(NSData*)data toFile:(NSString*)fullPath withParentRevision:(NSString*)parent_rev overwrite:(BOOL)overwrite completionHandler:(void(^)(NSDictionary*,NSError*))completionHandler {
	[self checkAccessTokenWithCompletionHandler:^(NSError *error) {
		if(error) {
			completionHandler(nil, error);
			return;
		}
		NSMutableURLRequest *req = [[GCOAuth URLRequestForPath:[NSString stringWithFormat:@"/1/files_put/%@/%@", self.useAppFolder?@"sandbox":@"dropbox", fullPath]
												 PUTParameters:[NSDictionary dictionaryWithObjectsAndKeys:
																overwrite?@"true":@"false", @"overwrite",
																parent_rev, @"parent_rev", // this might not exist
																nil]
														scheme:@"https"
														  host:@"api-content.dropbox.com"
												   consumerKey:gConsumerKey
												consumerSecret:gConsumerSecret
												   accessToken:self.oauth_token
												   tokenSecret:self.oauth_token_secret] mutableCopy];
		[req setHTTPBody:data];
		[req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
		[req setValue:[NSString stringWithFormat:@"%zu",[data length]] forHTTPHeaderField:@"Content-Length"];
		
		AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:req success:^(AFHTTPRequestOperation *operation, id responseObject) {
			completionHandler(responseObject, nil);
		} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
			if([[error domain] isEqualToString:@"com.monitzer.DropboxREST"] && [error code] == 401)
				[self uploadData:data toFile:fullPath withParentRevision:parent_rev overwrite:overwrite completionHandler:completionHandler
				 ]; // try again
			else
				completionHandler(nil, error);
		}];
		[self enqueueHTTPRequestOperation:op];
		[req release];
	}];
}

- (void)getFileAtPath:(NSString*)fullpath revision:(NSString*)rev completionHandler:(void(^)(NSData *content, NSError *error))completionHandler {
	NSAssert(fullpath, @"getFileAtPath: requires a path to retrieve!");
	[self checkAccessTokenWithCompletionHandler:^(NSError *error) {
		if(error) {
			completionHandler(nil, error);
			return;
		}
		NSURLRequest *req = [GCOAuth URLRequestForPath:[NSString stringWithFormat:@"/1/files/%@/%@", self.useAppFolder?@"sandbox":@"dropbox", fullpath]
										 GETParameters:[NSDictionary dictionaryWithObjectsAndKeys:
														rev, @"rev", nil]
												scheme:@"https"
												  host:@"api-content.dropbox.com"
										   consumerKey:gConsumerKey
										consumerSecret:gConsumerSecret
										   accessToken:self.oauth_token
										   tokenSecret:self.oauth_token_secret];
		AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:req success:^(AFHTTPRequestOperation *operation, id responseObject) {
			completionHandler(responseObject, nil);
		} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
			if([[error domain] isEqualToString:@"com.monitzer.DropboxREST"] && [error code] == 401)
				[self getFileAtPath:fullpath revision:rev completionHandler:completionHandler]; // try again
			else
				completionHandler(nil, error);
		}];
		
		[self enqueueHTTPRequestOperation:op];
	}];
}

- (void)shareFileAtPath:(NSString*)fullpath completionHandler:(void(^)(NSDictionary *info, NSError *error))completionHandler {
	[self checkAccessTokenWithCompletionHandler:^(NSError *error) {
		if(error) {
			completionHandler(nil, error);
			return;
		}
		NSMutableURLRequest *req = [[GCOAuth URLRequestForPath:[NSString stringWithFormat:@"/1/shares/%@/%@", self.useAppFolder?@"sandbox":@"dropbox", fullpath]
												POSTParameters:nil
														  host:@"api.dropbox.com"
												   consumerKey:gConsumerKey
												consumerSecret:gConsumerSecret
												   accessToken:self.oauth_token
												   tokenSecret:self.oauth_token_secret] mutableCopy];
		[req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
		
		AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:req success:^(AFHTTPRequestOperation *operation, id responseObject) {
			completionHandler(responseObject, nil);
		} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
			if([[error domain] isEqualToString:@"com.monitzer.DropboxREST"] && [error code] == 401)
				[self shareFileAtPath:fullpath completionHandler:completionHandler]; // try again
			else
				completionHandler(nil, error);
		}];
		[self enqueueHTTPRequestOperation:op];
		[req release];
	}];
}

#pragma mark - File Operations

- (void)deletePath:(NSString*)fullPath completionHandler:(void(^)(NSDictionary*,NSError*))completionHandler {
	[self checkAccessTokenWithCompletionHandler:^(NSError *error) {
		if(error) {
			completionHandler(nil, error);
			return;
		}
		NSMutableURLRequest *req = [[GCOAuth URLRequestForPath:@"/1/fileops/delete"
												POSTParameters:[NSDictionary dictionaryWithObjectsAndKeys:
																self.useAppFolder?@"sandbox":@"dropbox", @"root",
																fullPath, @"path",
																nil]
														  host:@"api.dropbox.com"
												   consumerKey:gConsumerKey
												consumerSecret:gConsumerSecret
												   accessToken:self.oauth_token
												   tokenSecret:self.oauth_token_secret] mutableCopy];
		[req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
		
		AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:req success:^(AFHTTPRequestOperation *operation, id responseObject) {
			completionHandler(responseObject, nil);
		} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
			if([[error domain] isEqualToString:@"com.monitzer.DropboxREST"] && [error code] == 401)
				[self deletePath:fullPath completionHandler:completionHandler]; // try again
			else
				completionHandler(nil, error);
		}];
		[self enqueueHTTPRequestOperation:op];
		[req release];
	}];
}

- (void)createFolderAtPath:(NSString*)fullPath completionHandler:(void(^)(NSDictionary *metadata,NSError *error))completionHandler {
	[self checkAccessTokenWithCompletionHandler:^(NSError *error) {
		if(error) {
			completionHandler(nil, error);
			return;
		}
		NSMutableURLRequest *req = [[GCOAuth URLRequestForPath:@"/1/fileops/create_folder"
												POSTParameters:[NSDictionary dictionaryWithObjectsAndKeys:
																self.useAppFolder?@"sandbox":@"dropbox", @"root",
																fullPath, @"path",
																nil]
														  host:@"api.dropbox.com"
												   consumerKey:gConsumerKey
												consumerSecret:gConsumerSecret
												   accessToken:self.oauth_token
												   tokenSecret:self.oauth_token_secret] mutableCopy];
		[req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
		
		AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:req success:^(AFHTTPRequestOperation *operation, id responseObject) {
			completionHandler(responseObject, nil);
		} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
			if([[error domain] isEqualToString:@"com.monitzer.DropboxREST"] && [error code] == 401)
				[self createFolderAtPath:fullPath completionHandler:completionHandler]; // try again
			else
				completionHandler(nil, error);
		}];
		[self enqueueHTTPRequestOperation:op];
		[req release];
	}];
}

- (void)copyItemAtPath:(NSString*)from_fullPath toPath:(NSString*)to_fullPath completionHandler:(void(^)(NSDictionary *metadata,NSError *error))completionHandler {
	[self checkAccessTokenWithCompletionHandler:^(NSError *error) {
		if(error) {
			completionHandler(nil, error);
			return;
		}
		NSMutableURLRequest *req = [[GCOAuth URLRequestForPath:@"/1/fileops/copy"
												POSTParameters:[NSDictionary dictionaryWithObjectsAndKeys:
																self.useAppFolder?@"sandbox":@"dropbox", @"root",
																from_fullPath, @"from_path",
																to_fullPath, @"to_path",
																nil]
														  host:@"api.dropbox.com"
												   consumerKey:gConsumerKey
												consumerSecret:gConsumerSecret
												   accessToken:self.oauth_token
												   tokenSecret:self.oauth_token_secret] mutableCopy];
		[req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
		
		AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:req success:^(AFHTTPRequestOperation *operation, id responseObject) {
			completionHandler(responseObject, nil);
		} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
			if([[error domain] isEqualToString:@"com.monitzer.DropboxREST"] && [error code] == 401)
				[self copyItemAtPath:from_fullPath toPath:to_fullPath completionHandler:completionHandler]; // try again
			else
				completionHandler(nil, error);
		}];
		[self enqueueHTTPRequestOperation:op];
		[req release];
	}];
}

- (void)moveItemAtPath:(NSString*)from_fullPath toPath:(NSString*)to_fullPath completionHandler:(void(^)(NSDictionary *metadata,NSError *error))completionHandler {
	[self checkAccessTokenWithCompletionHandler:^(NSError *error) {
		if(error) {
			completionHandler(nil, error);
			return;
		}
		NSMutableURLRequest *req = [[GCOAuth URLRequestForPath:@"/1/fileops/move"
												POSTParameters:[NSDictionary dictionaryWithObjectsAndKeys:
																self.useAppFolder?@"sandbox":@"dropbox", @"root",
																from_fullPath, @"from_path",
																to_fullPath, @"to_path",
																nil]
														  host:@"api.dropbox.com"
												   consumerKey:gConsumerKey
												consumerSecret:gConsumerSecret
												   accessToken:self.oauth_token
												   tokenSecret:self.oauth_token_secret] mutableCopy];
		[req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
		
		AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:req success:^(AFHTTPRequestOperation *operation, id responseObject) {
			completionHandler(responseObject, nil);
		} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
			if([[error domain] isEqualToString:@"com.monitzer.DropboxREST"] && [error code] == 401)
				[self moveItemAtPath:from_fullPath toPath:to_fullPath completionHandler:completionHandler]; // try again
			else
				completionHandler(nil, error);
		}];
		[self enqueueHTTPRequestOperation:op];
		[req release];
	}];
}

#pragma mark - High Level Interface

- (DBDropboxFolder*)rootFolder {
	return [[[DBDropboxFolder alloc] initWithPath:nil revision:nil client:self] autorelease];
}

@end
