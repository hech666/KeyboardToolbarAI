#import <UIKit/UIKit.h>
#import "HaogeKeyboardToolbarAIModel.h"
#import "HaogeKeyboardToolbarAINetwork.h"
#include <stdio.h>
#include <stdlib.h>
static unsigned haoge_keyboardtoolbarai_checks;
#define HG_TEST(...) do {++haoge_keyboardtoolbarai_checks;if (!(__VA_ARGS__)){fprintf(stderr,"FAIL %s:%d %s\n",__FILE__,__LINE__,#__VA_ARGS__);abort();}}while(0)
static HaogeKeyboardToolbarAIStreamDecoder *haoge_keyboardtoolbarai_decode(NSString *wire,BOOL split) {
    HaogeKeyboardToolbarAIStreamDecoder *d=[HaogeKeyboardToolbarAIStreamDecoder new];
    NSData *data=[wire dataUsingEncoding:NSUTF8StringEncoding];
    if (split) for(NSUInteger i=0;i<data.length;++i) [d haoge_keyboardtoolbarai_appendData:[data subdataWithRange:NSMakeRange(i,1)]];
    else [d haoge_keyboardtoolbarai_appendData:data];
    [d haoge_keyboardtoolbarai_finish];return d;
}
int main(void) { @autoreleasepool {
    HG_TEST(haoge_keyboardtoolbarai_actionCatalog().count==18);
    HG_TEST(haoge_keyboardtoolbarai_defaultButtons().count==12);
    HG_TEST(haoge_keyboardtoolbarai_providerPresets().count==8);
    HG_TEST([haoge_keyboardtoolbarai_normalizeButtons(@[@"copyText",@"paste",@"paste",@"invalid",@4]) isEqual:@[@"selectAllAndCopy",@"paste"]]);
    HG_TEST([haoge_keyboardtoolbarai_bindingAction(@{},@"paste",0) isEqual:@"paste"]);
    HG_TEST(haoge_keyboardtoolbarai_bindingAction(@{},@"paste",1)==nil);
    NSDictionary *map=haoge_keyboardtoolbarai_storeBinding(@{},@"paste",0,nil);
    HG_TEST([map[@"paste"][@"tap"] isEqual:@""]);
    HG_TEST(haoge_keyboardtoolbarai_bindingAction(map,@"paste",0)==nil);
    map=haoge_keyboardtoolbarai_storeBinding(map,@"paste",1,@"copyText");
    HG_TEST([haoge_keyboardtoolbarai_bindingAction(map,@"paste",1) isEqual:@"selectAllAndCopy"]);
    HG_TEST([haoge_keyboardtoolbarai_normalizeEndpoint(@" https://example.invalid/v1/chat/completions/ ") isEqual:@"https://example.invalid/v1"]);
    HG_TEST([haoge_keyboardtoolbarai_normalizeEndpoint(@"https://example.invalid/v1/models") isEqual:@"https://example.invalid/v1"]);
    for(id bad in @[@4,@"http://example.invalid",@"https://u:p@example.invalid",@"https://example.invalid?x=1",@"https://example.invalid#x",@"not-a-url"]) HG_TEST(haoge_keyboardtoolbarai_normalizeEndpoint(bad)==nil);
    NSDictionary *configuration=haoge_keyboardtoolbarai_normalizeAIConfiguration(nil);
    HG_TEST([configuration[@"stream"] boolValue]);HG_TEST([configuration[@"personas"] count]==3);
    configuration=haoge_keyboardtoolbarai_normalizeAIConfiguration(@{@"profiles":@[],@"personas":@[]});
    HG_TEST([configuration[@"personas"] count]==0);
    CGFloat r=0,g=0,b=0,a=0;[haoge_keyboardtoolbarai_colorFromHex(@"#80FF0000") getRed:&r green:&g blue:&b alpha:&a];
    HG_TEST(fabs(r-1)<0.001&&g==0&&b==0&&fabs(a-128.0/255)<0.001);
    HG_TEST(haoge_keyboardtoolbarai_colorFromHex(@"bad length")==nil);
    NSString *wire=@"data: {\"choices\":[{\"delta\":{\"content\":\"你好🌍\"}}]}\r\n\r\ndata: [DONE]\r\n\r\n";
    HaogeKeyboardToolbarAIStreamDecoder *d=haoge_keyboardtoolbarai_decode(wire,YES);
    HG_TEST(d.finished);HG_TEST(!d.error);HG_TEST([d.text isEqual:@"你好🌍"]);
    HG_TEST([haoge_keyboardtoolbarai_decode(wire,NO).text isEqual:d.text]);
    d=haoge_keyboardtoolbarai_decode(@"data: {\"choices\":[{\"delta\":{\"reasoning_content\":\"thinking\"},\"finish_reason\":\"stop\"}]}\n\n",YES);
    HG_TEST(d.hasReasoning);HG_TEST(d.finished);HG_TEST(!d.error);HG_TEST(d.text.length==0);
    d=haoge_keyboardtoolbarai_decode(@"data: {\"choices\":[{\"delta\":{\"content\":\"partial\"}}]}\n\n",NO);
    HG_TEST(d.error!=nil);HG_TEST([d.text isEqual:@"partial"]);
    d=haoge_keyboardtoolbarai_decode(@"data: {not-json}\n\n",NO);HG_TEST(d.error!=nil);
    d=haoge_keyboardtoolbarai_decode(@"data: {\"error\":{\"message\":\"test rejection\"}}\n\n",NO);HG_TEST(d.error!=nil);
    d=haoge_keyboardtoolbarai_decode(@": keepalive\n\ndata: [DONE]\n\n",NO);HG_TEST(d.finished&&!d.error);
    NSData *invalid=[NSData dataWithBytes:(const unsigned char[]){0xff,0x0a} length:2];d=[HaogeKeyboardToolbarAIStreamDecoder new];[d haoge_keyboardtoolbarai_appendData:invalid];HG_TEST(d.error!=nil);
    printf("{\"test\":\"native model and SSE no-network tests\",\"assertions\":%u,\"passed\":true}\n",haoge_keyboardtoolbarai_checks);
    return 0;
}}
