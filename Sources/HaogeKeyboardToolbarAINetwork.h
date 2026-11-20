#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

NS_ASSUME_NONNULL_BEGIN

// Call on the main thread. Starts the job and returns a copied cancellation
// block; the block may be called repeatedly from any thread. Callbacks are
// asynchronous on main. Streaming updates contain the entire visible text.
// completion receives either {text|models, timing} or an error, exactly once.
FOUNDATION_EXPORT dispatch_block_t haoge_keyboardtoolbarai_startAIJob(
    NSDictionary *options,
    void (^ _Nullable update)(NSString *text),
    void (^ _Nullable completion)(NSDictionary * _Nullable result, NSError * _Nullable error));

// Serial-use, UIKit-independent decoder. Terminal upon an error, [DONE], or
// finish. Feed arbitrary byte chunks and call finish once at EOF.
@interface HaogeKeyboardToolbarAIStreamDecoder : NSObject
@property (nonatomic, readonly, copy) NSString *text;
@property (nonatomic, readonly, strong, nullable) NSError *error;
@property (nonatomic, readonly) BOOL finished;
@property (nonatomic, readonly) BOOL hasReasoning;
- (void)haoge_keyboardtoolbarai_appendData:(NSData *)data;
- (void)haoge_keyboardtoolbarai_finish;
@end

NS_ASSUME_NONNULL_END
