#import "HaogeKeyboardToolbarAINetwork.h"
#import "HaogeKeyboardToolbarAIModel.h"
#import <QuartzCore/QuartzCore.h>

static NSString * const haoge_keyboardtoolbarai_networkErrorDomain = @"com.haoge.keyboardtoolbarai.network";
static const NSUInteger haoge_keyboardtoolbarai_streamLimit = 262144;

static NSError *haoge_keyboardtoolbarai_error(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:haoge_keyboardtoolbarai_networkErrorDomain code:code
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @"Network request failed."}];
}

@interface HaogeKeyboardToolbarAIStreamDecoder ()
@property(nonatomic, copy) NSString *text;
@property(nonatomic, strong, nullable) NSError *error;
@property(nonatomic) BOOL finished;
@property(nonatomic) BOOL hasReasoning;
@property(nonatomic, strong) NSMutableData *lineBuffer;
@property(nonatomic, strong) NSMutableString *eventData;
@property(nonatomic, strong) NSMutableString *output;
@property(nonatomic) BOOL sawFinishReason;
@end

@implementation HaogeKeyboardToolbarAIStreamDecoder
- (instancetype)init {
    if ((self = [super init])) {
        _lineBuffer = [NSMutableData data]; _eventData = [NSMutableString string];
        _output = [NSMutableString string]; _text = @"";
    }
    return self;
}
- (void)haoge_keyboardtoolbarai_fail:(NSString *)message {
    if (self.finished) return;
    self.error = haoge_keyboardtoolbarai_error(1, message);
    self.finished = YES;
}
- (void)haoge_keyboardtoolbarai_consumeEvent {
    if (self.finished) return;
    NSString *line = [self.eventData stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    [self.eventData setString:@""];
    if (!line.length) return;
    if ([line isEqualToString:@"[DONE]"]) { self.finished = YES; return; }
    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
    id object = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
    if (![object isKindOfClass:NSDictionary.class]) { [self haoge_keyboardtoolbarai_fail:@"无法解析流式响应。"] ; return; }
    id apiError = object[@"error"];
    if (apiError && apiError != NSNull.null) {
        id message = [apiError isKindOfClass:NSDictionary.class] ? apiError[@"message"] : apiError;
        [self haoge_keyboardtoolbarai_fail:[message isKindOfClass:NSString.class] ? message : @"服务返回错误。"];
        return;
    }
    NSArray *choices = [object[@"choices"] isKindOfClass:NSArray.class] ? object[@"choices"] : nil;
    id first = [choices.firstObject isKindOfClass:NSDictionary.class] ? choices.firstObject : nil;
    if (![first isKindOfClass:NSDictionary.class]) return;
    NSDictionary *delta = [first[@"delta"] isKindOfClass:NSDictionary.class] ? first[@"delta"] : nil;
    for (NSString *key in @[@"reasoning_content", @"reasoning", @"reasoning_details", @"thinking"]) {
        id value = delta[key];
        if (([value isKindOfClass:NSString.class] && [value length]) ||
            ([value isKindOfClass:NSArray.class] && [value count]) ||
            ([value isKindOfClass:NSDictionary.class] && [value count])) { self.hasReasoning = YES; break; }
    }
    if ([first[@"finish_reason"] isKindOfClass:NSString.class]) self.sawFinishReason = YES;
    id content = [delta[@"content"] isKindOfClass:NSString.class] ? delta[@"content"] : nil;
    if (!content) return;
    if (self.output.length + [content length] > haoge_keyboardtoolbarai_streamLimit) {
        [self haoge_keyboardtoolbarai_fail:@"回答过长，已停止接收。"]; return;
    }
    [self.output appendString:content]; self.text = self.output.copy;
}
- (void)haoge_keyboardtoolbarai_consumeLine:(NSData *)bytes {
    NSString *line = [[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding];
    if (!line) { [self haoge_keyboardtoolbarai_fail:@"流式响应不是有效的 UTF-8 文本。"]; return; }
    if ([line hasSuffix:@"\r"]) line = [line substringToIndex:line.length - 1];
    if (!line.length) { [self haoge_keyboardtoolbarai_consumeEvent]; return; }
    if (![line hasPrefix:@"data:"]) return;
    NSString *piece = [line substringFromIndex:5];
    if ([piece hasPrefix:@" "]) piece = [piece substringFromIndex:1];
    if (self.eventData.length) [self.eventData appendString:@"\n"];
    [self.eventData appendString:piece];
    if (self.eventData.length > haoge_keyboardtoolbarai_streamLimit)
        [self haoge_keyboardtoolbarai_fail:@"单条流式事件过大。"];
}
- (void)haoge_keyboardtoolbarai_appendData:(NSData *)data {
    if (self.finished || !data.length) return;
    [self.lineBuffer appendData:data];
    if (self.lineBuffer.length > haoge_keyboardtoolbarai_streamLimit) {
        [self haoge_keyboardtoolbarai_fail:@"单条流式响应过大。"]; return;
    }
    const uint8_t *bytes = self.lineBuffer.bytes; NSUInteger start = 0;
    for (NSUInteger i = 0; i < self.lineBuffer.length && !self.finished; i++) {
        if (bytes[i] != '\n') continue;
        [self haoge_keyboardtoolbarai_consumeLine:[self.lineBuffer subdataWithRange:NSMakeRange(start, i-start)]];
        start = i + 1;
    }
    if (start) [self.lineBuffer replaceBytesInRange:NSMakeRange(0, start) withBytes:NULL length:0];
}
- (void)haoge_keyboardtoolbarai_finish {
    if (self.finished) return;
    if (self.lineBuffer.length) [self haoge_keyboardtoolbarai_consumeLine:self.lineBuffer];
    [self.lineBuffer setLength:0]; [self haoge_keyboardtoolbarai_consumeEvent];
    if (!self.finished && !self.sawFinishReason)
        [self haoge_keyboardtoolbarai_fail:@"流式连接提前结束，已保留收到的内容。"];
    else if (!self.finished) self.finished = YES;
}
@end

static BOOL haoge_keyboardtoolbarai_isString(id value) { return [value isKindOfClass:NSString.class]; }
static BOOL haoge_keyboardtoolbarai_validateJPEGDataURL(NSString *url) {
    if (![url hasPrefix:@"data:image/jpeg;base64,"]) return NO;
    if (url.length>1400000) return NO;
    NSString *encoded = [url substringFromIndex:[@"data:image/jpeg;base64," length]];
    NSData *data = [[NSData alloc] initWithBase64EncodedString:encoded options:0];
    const uint8_t *p = data.bytes;
    return data.length >= 3 && data.length<=1048576 && p[0] == 0xff && p[1] == 0xd8 && p[2] == 0xff;
}
static NSError *haoge_keyboardtoolbarai_validateMessages(NSArray *messages, NSUInteger *imageTotal) {
    if (![messages isKindOfClass:NSArray.class] || messages.count < 1 || messages.count > 41)
        return haoge_keyboardtoolbarai_error(2, @"消息数量必须为 1 到 41 条。");
    NSUInteger images = 0, textUnits = 0;
    NSSet *roles = [NSSet setWithArray:@[@"system", @"user", @"assistant"]];
    for (id item in messages) {
        if (![item isKindOfClass:NSDictionary.class]) return haoge_keyboardtoolbarai_error(2, @"消息格式无效。");
        NSString *role = item[@"role"]; id content = item[@"content"];
        if (!haoge_keyboardtoolbarai_isString(role) || ![roles containsObject:role] || !content) return haoge_keyboardtoolbarai_error(2, @"消息角色或内容无效。");
        if (haoge_keyboardtoolbarai_isString(content)) {
            textUnits += [content length];
        } else if ([content isKindOfClass:NSArray.class]) {
            if ([content count]<1 || [content count]>5) return haoge_keyboardtoolbarai_error(2,@"每条图文消息仅支持文本及最多4张图片。");
            NSUInteger perUserImages = 0;
            for (id part in content) {
                if (![part isKindOfClass:NSDictionary.class]) return haoge_keyboardtoolbarai_error(2, @"消息内容格式无效。");
                if ([part[@"type"] isEqual:@"text"] && haoge_keyboardtoolbarai_isString(part[@"text"])) {
                    textUnits += [part[@"text"] length];
                } else if ([part[@"type"] isEqual:@"image_url"] && [role isEqual:@"user"]) {
                    id image = part[@"image_url"]; NSString *url = [image isKindOfClass:NSDictionary.class] ? image[@"url"] : nil;
                    if (!haoge_keyboardtoolbarai_isString(url) || !haoge_keyboardtoolbarai_validateJPEGDataURL(url))
                        return haoge_keyboardtoolbarai_error(2, @"仅接受有效的 JPEG data URL 图片。");
                    if (++perUserImages > 4) return haoge_keyboardtoolbarai_error(2, @"每条用户消息最多包含 4 张图片。");
                    images++;
                } else return haoge_keyboardtoolbarai_error(2, @"不支持的消息内容类型。");
            }
        } else return haoge_keyboardtoolbarai_error(2, @"消息内容必须为文本或内容数组。");
        if (textUnits > 262144) return haoge_keyboardtoolbarai_error(2, @"输入文本过长。");
    }
    if (imageTotal) *imageTotal = images;
    return nil;
}

@interface HaogeKeyboardToolbarAINetworkJob : NSObject <NSURLSessionDataDelegate, NSURLSessionTaskDelegate>
@property(nonatomic, strong) NSLock *lock;
@property(nonatomic, strong) NSOperationQueue *haoge_keyboardtoolbarai_workQueue;
@property(nonatomic, strong, nullable) NSURLSession *session;
@property(nonatomic, strong, nullable) NSURLSessionDataTask *task;
@property(nonatomic, strong) NSMutableData *body;
@property(nonatomic, strong, nullable) HaogeKeyboardToolbarAIStreamDecoder *decoder;
@property(nonatomic, copy) void (^ _Nullable update)(NSString *);
@property(nonatomic, copy) void (^ _Nullable completion)(NSDictionary *, NSError *);
@property(nonatomic, copy) void (^ _Nullable timingUpdate)(NSDictionary *);
@property(nonatomic, copy) NSDictionary *options;
@property(nonatomic, copy) NSString *endpoint;
@property(nonatomic, copy) NSString *host;
@property(nonatomic, copy) NSString *model;
@property(nonatomic) BOOL modelsRequest;
@property(nonatomic) BOOL streaming;
@property(nonatomic) BOOL sse;
@property(nonatomic) BOOL terminal;
@property(nonatomic) BOOL uploadRecorded;
@property(nonatomic) BOOL firstTextRecorded;
@property(nonatomic) BOOL reasoningRecorded;
@property(nonatomic) NSInteger statusCode;
@property(nonatomic) NSUInteger imageCount;
@property(nonatomic) NSUInteger messageCount;
@property(nonatomic) NSUInteger requestBytes;
@property(nonatomic) NSUInteger haoge_keyboardtoolbarai_responseBytes;
@property(nonatomic) CFTimeInterval startedAt;
@property(nonatomic) CFTimeInterval preparedDuration;
@property(nonatomic) CFTimeInterval networkStartedAt;
@property(nonatomic) CFTimeInterval uploadFinishedAt;
@property(nonatomic) CFTimeInterval headersAt;
@property(nonatomic) CFTimeInterval firstDataAt;
@property(nonatomic) CFTimeInterval firstTextAt;
@property(nonatomic) CFTimeInterval reasoningAt;
- (void)haoge_keyboardtoolbarai_start;
- (void)haoge_keyboardtoolbarai_cancel;
- (BOOL)haoge_keyboardtoolbarai_isTerminal;
@end

@implementation HaogeKeyboardToolbarAINetworkJob
- (instancetype)init {
    if ((self = [super init])) { _lock = [NSLock new]; _body = [NSMutableData data]; _startedAt = CACurrentMediaTime(); _haoge_keyboardtoolbarai_workQueue=[NSOperationQueue new];_haoge_keyboardtoolbarai_workQueue.maxConcurrentOperationCount=1;_haoge_keyboardtoolbarai_workQueue.name=@"com.haoge.keyboardtoolbarai.request-state"; }
    return self;
}
- (BOOL)haoge_keyboardtoolbarai_isTerminal {
    [self.lock lock]; BOOL value = self.terminal; [self.lock unlock]; return value;
}
- (NSDictionary *)haoge_keyboardtoolbarai_timing {
    CFTimeInterval now = CACurrentMediaTime();
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"prepared_ms"] = @(self.preparedDuration * 1000.0);
    d[@"network_ms"] = @((self.networkStartedAt > 0 ? (self.headersAt > 0 ? self.headersAt : now) - self.networkStartedAt : 0) * 1000.0);
    d[@"upload_ms"] = @(self.uploadFinishedAt > 0 && self.networkStartedAt > 0 ? (self.uploadFinishedAt-self.networkStartedAt)*1000.0 : 0);
    d[@"first_data_ms"] = @(self.firstDataAt > 0 && self.networkStartedAt > 0 ? (self.firstDataAt-self.networkStartedAt)*1000.0 : 0);
    d[@"first_text_ms"] = @(self.firstTextAt > 0 && self.networkStartedAt > 0 ? (self.firstTextAt-self.networkStartedAt)*1000.0 : 0);
    d[@"reasoning_ms"] = @(self.reasoningAt > 0 && self.networkStartedAt > 0 ? (self.reasoningAt-self.networkStartedAt)*1000.0 : 0);
    d[@"headers_ms"] = @(self.headersAt > 0 && self.networkStartedAt > 0 ? (self.headersAt-self.networkStartedAt)*1000.0 : 0);
    d[@"request_bytes"] = @(self.requestBytes); d[@"image_count"] = @(self.imageCount);
    d[@"message_count"] = @(self.messageCount); d[@"endpoint_host"] = self.host ?: @"";
    d[@"model"] = self.modelsRequest ? @"" : (self.model ?: @"");
    return d.copy;
}
- (void)haoge_keyboardtoolbarai_reportTiming {
    if (!self.timingUpdate) return;
    NSDictionary *timing = [self haoge_keyboardtoolbarai_timing];
    void (^callback)(NSDictionary *) = self.timingUpdate;
    dispatch_async(dispatch_get_main_queue(), ^{ if (![self haoge_keyboardtoolbarai_isTerminal]) callback(timing); });
}
- (void)haoge_keyboardtoolbarai_complete:(NSDictionary *)result error:(NSError *)error {
    [self.lock lock];
    if (self.terminal) { [self.lock unlock]; return; }
    self.terminal = YES;
    void (^callback)(NSDictionary *, NSError *) = self.completion;
    self.completion = nil; self.update = nil; self.timingUpdate = nil;
    NSURLSession *session = self.session;
    [self.lock unlock];
    NSMutableDictionary *final = [result mutableCopy] ?: [NSMutableDictionary dictionary];
    final[@"timing"] = [self haoge_keyboardtoolbarai_timing];
    [session finishTasksAndInvalidate];
    dispatch_async(dispatch_get_main_queue(), ^{ if (callback) callback(final.copy, error); });
}
- (void)haoge_keyboardtoolbarai_cancel {
    [self.haoge_keyboardtoolbarai_workQueue addOperationWithBlock:^{ [self haoge_keyboardtoolbarai_cancelOnQueue]; }];
}
- (void)haoge_keyboardtoolbarai_cancelOnQueue {
    [self.lock lock];
    BOOL done = self.terminal;
    NSURLSessionDataTask *task = self.task;
    NSURLSession *session = self.session;
    [self.lock unlock];
    if (done) return;
    [self haoge_keyboardtoolbarai_complete:nil error:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:@{NSLocalizedDescriptionKey: @"请求已取消。"}]];
    [task cancel];
    [session invalidateAndCancel];
}
- (void)haoge_keyboardtoolbarai_emitText:(NSString *)text {
    if (!self.update || [self haoge_keyboardtoolbarai_isTerminal]) return;
    void (^callback)(NSString *) = self.update;
    NSString *snapshot = [text copy];
    dispatch_async(dispatch_get_main_queue(), ^{ if (![self haoge_keyboardtoolbarai_isTerminal]) callback(snapshot); });
}
- (void)haoge_keyboardtoolbarai_start {
    if ([self haoge_keyboardtoolbarai_isTerminal]) return;
    CFTimeInterval prepStart = CACurrentMediaTime();
    NSDictionary *profile = [self.options[@"profile"] isKindOfClass:NSDictionary.class] ? self.options[@"profile"] : nil;
    NSString *rawEndpoint = profile[@"endpoint"];
    self.modelsRequest = [self.options[@"kind"] isEqual:@"models"];
    self.streaming = !self.modelsRequest && [self.options[@"stream"] boolValue];
    self.model = [self.options[@"model"] isKindOfClass:NSString.class] ? self.options[@"model"] : profile[@"model"];
    NSString *secret = [profile[@"key"] isKindOfClass:NSString.class] ? [profile[@"key"] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : @"";
    self.endpoint = haoge_keyboardtoolbarai_normalizeEndpoint(rawEndpoint);
    NSURLComponents *endpointParts = self.endpoint ? [NSURLComponents componentsWithString:self.endpoint] : nil;
    self.host = endpointParts.host.lowercaseString ?: @"";
    if (!self.endpoint.length || self.endpoint.length>8192 || !secret.length || secret.length>8192 || [secret rangeOfCharacterFromSet:NSCharacterSet.newlineCharacterSet].location!=NSNotFound) {
        [self haoge_keyboardtoolbarai_complete:nil error:haoge_keyboardtoolbarai_error(2, @"请配置有效的 HTTPS 端点和 API Key。")]; return;
    }
    NSMutableURLRequest *request = nil;
    if (self.modelsRequest) {
        NSString *base = self.endpoint;
        BOOL google = [self.host isEqualToString:@"generativelanguage.googleapis.com"];
        if (google && [base hasSuffix:@"/openai"]) base = [base substringToIndex:base.length-7];
        NSURL *url = [NSURL URLWithString:[base stringByAppendingString:@"/models"]];
        if (!url || ![url.scheme.lowercaseString isEqual:@"https"] || ![url.host.lowercaseString isEqual:self.host]) {
            [self haoge_keyboardtoolbarai_complete:nil error:haoge_keyboardtoolbarai_error(2, @"模型列表 URL 无效。")]; return;
        }
        request = [NSMutableURLRequest requestWithURL:url]; request.HTTPMethod = @"GET";
        if (google) [request setValue:secret forHTTPHeaderField:@"x-goog-api-key"];
        else [request setValue:[@"Bearer " stringByAppendingString:secret] forHTTPHeaderField:@"Authorization"];
    } else {
        NSArray *messages = self.options[@"messages"];
        NSError *validation = haoge_keyboardtoolbarai_validateMessages(messages, &_imageCount);
        if (validation) { [self haoge_keyboardtoolbarai_complete:nil error:validation]; return; }
        self.messageCount = messages.count;
        if (!haoge_keyboardtoolbarai_isString(self.model) || !self.model.length || self.model.length>256)
            { [self haoge_keyboardtoolbarai_complete:nil error:haoge_keyboardtoolbarai_error(2, @"请选择模型。")]; return; }
        NSMutableDictionary *body = [@{@"model": self.model, @"messages": messages, @"stream": @(self.streaming)} mutableCopy];
        NSData *json = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
        if (!json || json.length > 16 * 1024 * 1024) {
            [self haoge_keyboardtoolbarai_complete:nil error:haoge_keyboardtoolbarai_error(2, @"请求内容无效或超过 16 MiB。")]; return;
        }
        self.requestBytes = json.length;
        NSURL *url = [NSURL URLWithString:[self.endpoint stringByAppendingString:@"/chat/completions"]];
        if (!url || ![url.scheme.lowercaseString isEqual:@"https"] || ![url.host.lowercaseString isEqual:self.host]) {
            [self haoge_keyboardtoolbarai_complete:nil error:haoge_keyboardtoolbarai_error(2, @"聊天请求 URL 无效。")]; return;
        }
        request = [NSMutableURLRequest requestWithURL:url]; request.HTTPMethod = @"POST";
        request.HTTPBody = json;
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:@"application/json, text/event-stream" forHTTPHeaderField:@"Accept"];
        [request setValue:[@"Bearer " stringByAppendingString:secret] forHTTPHeaderField:@"Authorization"];
    }
    request.timeoutInterval = 90.0;
    self.preparedDuration = CACurrentMediaTime() - prepStart;
    if ([self haoge_keyboardtoolbarai_isTerminal]) return;
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    configuration.URLCache = nil; configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    configuration.HTTPCookieStorage = nil; configuration.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyNever;
    configuration.URLCredentialStorage = nil; configuration.HTTPShouldSetCookies = NO;
    configuration.timeoutIntervalForRequest = 90.0; configuration.timeoutIntervalForResource = 300.0;
    self.session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:self.haoge_keyboardtoolbarai_workQueue];
    self.networkStartedAt = CACurrentMediaTime(); self.task = [self.session dataTaskWithRequest:request];
    if ([self haoge_keyboardtoolbarai_isTerminal]) { [self.task cancel]; [self.session invalidateAndCancel]; return; }
    [self.task resume]; [self haoge_keyboardtoolbarai_reportTiming];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    if ([self haoge_keyboardtoolbarai_isTerminal]) { completionHandler(NSURLSessionResponseCancel); return; }
    if (![response isKindOfClass:NSHTTPURLResponse.class]) { completionHandler(NSURLSessionResponseCancel); [self haoge_keyboardtoolbarai_complete:nil error:haoge_keyboardtoolbarai_error(3, @"服务器响应无效。")]; return; }
    NSHTTPURLResponse *http = (NSHTTPURLResponse *)response; self.statusCode = http.statusCode;
    self.headersAt = CACurrentMediaTime();
    NSString *mime = http.MIMEType.lowercaseString ?: @"";
    self.sse = self.statusCode>=200 && self.statusCode<300 && !self.modelsRequest && self.streaming && [mime isEqualToString:@"text/event-stream"];
    if (!self.modelsRequest && self.sse) self.decoder = [HaogeKeyboardToolbarAIStreamDecoder new];
    [self haoge_keyboardtoolbarai_reportTiming];
    completionHandler(NSURLSessionResponseAllow);
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler {
    NSURL *target = request.URL; NSURL *origin = task.currentRequest.URL;
    BOOL sameOrigin = target && origin &&
        [target.host.lowercaseString isEqualToString:origin.host.lowercaseString] &&
        (target.port ? target.port.integerValue : 443) == (origin.port ? origin.port.integerValue : 443);
    NSURLComponents *targetParts = target ? [NSURLComponents componentsWithURL:target resolvingAgainstBaseURL:NO] : nil;
    BOOL safe = sameOrigin && [target.scheme.lowercaseString isEqualToString:@"https"] &&
        [target.host.lowercaseString isEqualToString:self.host] &&
        [origin.scheme.lowercaseString isEqualToString:@"https"] && !targetParts.user && !targetParts.password &&
        !targetParts.fragment && [target.host.lowercaseString isEqualToString:origin.host.lowercaseString];
    completionHandler(safe ? request : nil);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {
    if ([self haoge_keyboardtoolbarai_isTerminal] || !data.length) return;
    if (!self.firstDataAt) { self.firstDataAt = CACurrentMediaTime(); [self haoge_keyboardtoolbarai_reportTiming]; }
    self.haoge_keyboardtoolbarai_responseBytes+=data.length;
    if (self.haoge_keyboardtoolbarai_responseBytes > 16 * 1024 * 1024) {
        [self haoge_keyboardtoolbarai_complete:nil error:haoge_keyboardtoolbarai_error(4, @"服务器响应超过 16 MiB。")]; [task cancel]; return;
    }
    if (self.sse && self.decoder) {
        BOOL hadReasoning = self.decoder.hasReasoning;
        NSString *before = self.decoder.text;
        [self.decoder haoge_keyboardtoolbarai_appendData:data];
        if (!hadReasoning && self.decoder.hasReasoning && !self.reasoningRecorded) {
            self.reasoningRecorded = YES; self.reasoningAt = CACurrentMediaTime(); [self haoge_keyboardtoolbarai_reportTiming];
        }
        NSString *visible = self.decoder.text;
        if (visible.length > before.length) {
            if (!self.firstTextRecorded) { self.firstTextRecorded = YES; self.firstTextAt = CACurrentMediaTime(); [self haoge_keyboardtoolbarai_reportTiming]; }
            [self haoge_keyboardtoolbarai_emitText:visible];
        }
        if (self.decoder.error) { [self haoge_keyboardtoolbarai_complete:nil error:self.decoder.error]; [task cancel]; }
        else if (self.decoder.finished) { [self haoge_keyboardtoolbarai_complete:@{@"text":self.decoder.text?:@""} error:nil]; [task cancel]; }
    } else [self.body appendData:data];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    if ([self haoge_keyboardtoolbarai_isTerminal]) return;
    if (totalBytesExpectedToSend > 0 && totalBytesSent >= totalBytesExpectedToSend && !self.uploadRecorded) {
        self.uploadRecorded = YES; self.uploadFinishedAt = CACurrentMediaTime(); [self haoge_keyboardtoolbarai_reportTiming];
    }
}
- (void)haoge_keyboardtoolbarai_reportFirstTextIfNeeded:(NSString *)text {
    if (text.length && !self.firstTextRecorded) {
        self.firstTextRecorded = YES; self.firstTextAt = CACurrentMediaTime(); [self haoge_keyboardtoolbarai_reportTiming];
    }
}
- (NSError *)haoge_keyboardtoolbarai_HTTPError {
    NSString *message = nil;
    id object = self.body.length ? [NSJSONSerialization JSONObjectWithData:self.body options:NSJSONReadingFragmentsAllowed error:NULL] : nil;
    id apiError = [object isKindOfClass:NSDictionary.class] ? object[@"error"] : nil;
    if ([apiError isKindOfClass:NSDictionary.class] && [apiError[@"message"] isKindOfClass:NSString.class]) message = apiError[@"message"];
    else if ([apiError isKindOfClass:NSString.class]) message = apiError;
    if (!message.length) message = [NSString stringWithFormat:@"HTTP 请求失败（%ld）。", (long)self.statusCode];
    return haoge_keyboardtoolbarai_error(self.statusCode ?: 5, message);
}
- (NSArray<NSString *> *)haoge_keyboardtoolbarai_modelNames:(id)object {
    id rows = nil;
    if ([object isKindOfClass:NSDictionary.class]) rows = object[@"data"] ?: object[@"models"];
    if (![rows isKindOfClass:NSArray.class]) return nil;
    NSMutableArray *names = [NSMutableArray array];
    for (id row in rows) {
        NSString *name = [row isKindOfClass:NSString.class] ? row :
            ([row isKindOfClass:NSDictionary.class] ? (row[@"id"] ?: row[@"name"]) : nil);
        if ([name isKindOfClass:NSString.class] && name.length) [names addObject:name];
    }
    return names.copy;
}
- (NSString *)haoge_keyboardtoolbarai_chatText:(id)object error:(NSError **)error {
    if (![object isKindOfClass:NSDictionary.class]) { if(error)*error=haoge_keyboardtoolbarai_error(5,@"服务器返回无效 JSON。"); return nil; }
    id apiError = object[@"error"];
    if (apiError && apiError != NSNull.null) {
        NSString *message = [apiError isKindOfClass:NSDictionary.class] ? apiError[@"message"] : apiError;
        if(error)*error=haoge_keyboardtoolbarai_error(5,[message isKindOfClass:NSString.class]?message:@"服务返回错误。"); return nil;
    }
    NSArray *choices = [object[@"choices"] isKindOfClass:NSArray.class] ? object[@"choices"] : nil;
    id first = [choices.firstObject isKindOfClass:NSDictionary.class] ? choices.firstObject : nil;
    id message = [first[@"message"] isKindOfClass:NSDictionary.class] ? first[@"message"] : nil;
    id content = message[@"content"];
    if ([content isKindOfClass:NSString.class]) return content;
    if ([content isKindOfClass:NSArray.class]) {
        NSMutableString *combined = [NSMutableString string];
        for (id part in content) if ([part isKindOfClass:NSDictionary.class] && [part[@"text"] isKindOfClass:NSString.class]) [combined appendString:part[@"text"]];
        if (combined.length) return combined.copy;
    }
    if (error) *error = haoge_keyboardtoolbarai_error(5, @"响应中没有可显示的文本。");
    return nil;
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)networkError {
    if ([self haoge_keyboardtoolbarai_isTerminal]) return;
    if (networkError) { [self haoge_keyboardtoolbarai_complete:nil error:networkError]; return; }
    if (self.statusCode < 200 || self.statusCode >= 300) { [self haoge_keyboardtoolbarai_complete:nil error:[self haoge_keyboardtoolbarai_HTTPError]]; return; }
    if (self.modelsRequest) {
        id object = self.body.length ? [NSJSONSerialization JSONObjectWithData:self.body options:0 error:NULL] : nil;
        NSArray *models = [self haoge_keyboardtoolbarai_modelNames:object];
        if (!models) { [self haoge_keyboardtoolbarai_complete:nil error:haoge_keyboardtoolbarai_error(5,@"模型列表响应格式无效。")]; return; }
        [self haoge_keyboardtoolbarai_complete:@{@"models":models} error:nil]; return;
    }
    if (self.sse && self.decoder) {
        [self.decoder haoge_keyboardtoolbarai_finish];
        if (self.decoder.error) { [self haoge_keyboardtoolbarai_complete:nil error:self.decoder.error]; return; }
        [self haoge_keyboardtoolbarai_reportFirstTextIfNeeded:self.decoder.text];
        [self haoge_keyboardtoolbarai_complete:@{@"text":self.decoder.text ?: @""} error:nil]; return;
    }
    id object = self.body.length ? [NSJSONSerialization JSONObjectWithData:self.body options:NSJSONReadingFragmentsAllowed error:NULL] : nil;
    NSError *parseError = nil;
    NSString *text = [self haoge_keyboardtoolbarai_chatText:object error:&parseError];
    if (!text) { [self haoge_keyboardtoolbarai_complete:nil error:parseError ?: haoge_keyboardtoolbarai_error(5,@"服务器返回无效 JSON。")]; return; }
    [self haoge_keyboardtoolbarai_reportFirstTextIfNeeded:text];
    [self haoge_keyboardtoolbarai_emitText:text];
    [self haoge_keyboardtoolbarai_complete:@{@"text":text} error:nil];
}
@end

// Entry point always arranges preparation on main; callers normally invoke it
// there. It starts immediately and returns only a cancellation block.
dispatch_block_t haoge_keyboardtoolbarai_startAIJob(NSDictionary *options,
    void (^update)(NSString *text), void (^completion)(NSDictionary *result, NSError *error)) {
    // Invalid options become an empty configuration and complete asynchronously
    // with a validation error. A nil completion is explicitly supported.
    HaogeKeyboardToolbarAINetworkJob *job = [HaogeKeyboardToolbarAINetworkJob new];
    job.options = [options isKindOfClass:NSDictionary.class] ? [options copy] : @{};
    job.update = [update copy]; job.completion = [completion copy];
    id timing = job.options[@"kt_timingUpdate"];
    Class blockClass = NSClassFromString(@"NSBlock");
    if (timing && blockClass && [timing isKindOfClass:blockClass]) job.timingUpdate = [timing copy];
    dispatch_block_t cancel = [^{ [job haoge_keyboardtoolbarai_cancel]; } copy];
    dispatch_block_t begin = ^{ [job.haoge_keyboardtoolbarai_workQueue addOperationWithBlock:^{ [job haoge_keyboardtoolbarai_start]; }]; };
    if (NSThread.isMainThread) begin(); else dispatch_async(dispatch_get_main_queue(), begin);
    return cancel;
}
