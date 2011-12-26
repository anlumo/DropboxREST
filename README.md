# DropboxREST

This framework implements parts of the Dropbox REST API, as described on [api.dropbox.com](https://api.dropbox.com/developers/reference/api).

## Usage

    #import <DropboxREST/DropboxREST.h>
    
    [DBDropboxClient setConsumerKey:@"..." andSecret:@"..."]; // from the Dropbox developer interface
    
    DBDropboxClient *client = [DBDropboxClient client];
    client.authenticationCallback = ^(NSString *oauth_token, void(^completionHandler)(NSError*)){
    	authenticationCompletionHandler = [completionHandler copy];
    	NSURLRequest *req = [client requestWithMethod:@"GET"
    	                                         path:@"https://www.dropbox.com/1/oauth/authorize"
    	                                   parameters:[NSDictionary dictionaryWithObjectsAndKeys:
    	                                               oauth_token, @"oauth_token",
    	                                               @"http://www.example.com", @"oauth_callback",
    	                                               [[NSLocale preferredLanguages] objectAtIndex:0], @"locale",
    	                                               nil]];
    	// display this request in a webview and wait for a request beginning with http://www.example.com
    	// when this request is received, call authenticationCompletionHandler(nil); and release it afterwards.
    	// If the user does not authenticate properly (e.g. by closing the window), call the block with an NSError parameter. This object will be returned back to you on whatever request caused the authentication to be requested.
    	// note that this block here might be called multiple times (e.g. when the user removes the authorization while the application is running).
    };

    
    DBDropboxFolder *root = [client rootFolder];
    
    [root getFilesWithCompletionHandler:^(NSSet *files, NSError *error) {
    	if(error)
    		[NSApp presentError:error];
    	else
    		NSLog(@"files: %@", files);
    }];

The framework creates an abstraction based on two classes: DBDropboxFile, representing a file, and DBDropboxFolder, representing a folder. All calls are asynchronous and nonblocking, as they all take a block for returning their result.

Note that DBDropboxFile does manage its revision, so conflict management should work properly. However, at the moment it's not possible to tell it to fetch the latest revision, whatever that might be. Directory listings always return the latest revision of the files contained in that directory.

## Missing Features

* /revisions
* /restore
* /search
* /media
* /thumbnails

The reason these were not implemented is simply that I don't need them. If you do implement them (tested!), please create a pull request!

## License

This project includes [cocoa-oauth](https://github.com/anlumo/cocoa-oauth.git) and [AFNetworking](https://github.com/AFNetworking/AFNetworking.git). Please refer to these projects for their corresponding licenses.

The code included in this git project:

Copyright 2011 Andreas Monitzer <andreas@monitzer.com>. All rights reserved.

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
