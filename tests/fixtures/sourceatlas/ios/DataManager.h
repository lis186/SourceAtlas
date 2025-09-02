#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol DataManagerDelegate;

@interface DataManager : NSObject

@property (nonatomic, strong) NSString *apiKey;
@property (nonatomic, weak) id<DataManagerDelegate> delegate;
@property (nonatomic, readonly) BOOL isConnected;

+ (instancetype)sharedInstance;
+ (void)configure:(NSString *)apiKey;

- (instancetype)initWithConfiguration:(NSDictionary *)config;
- (void)fetchDataWithCompletion:(void (^)(NSData *data, NSError *error))completion;
- (BOOL)validateData:(NSData *)data;

@end

@protocol DataManagerDelegate <NSObject>

@optional
- (void)dataManagerDidConnect:(DataManager *)manager;
- (void)dataManager:(DataManager *)manager didFailWithError:(NSError *)error;

@end