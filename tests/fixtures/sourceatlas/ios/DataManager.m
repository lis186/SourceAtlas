#import "DataManager.h"
#import "NetworkClient.h"

static DataManager *_sharedInstance = nil;

@interface DataManager ()

@property (nonatomic, strong) NetworkClient *networkClient;
@property (nonatomic, readwrite) BOOL isConnected;

@end

@implementation DataManager

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[DataManager alloc] init];
    });
    return _sharedInstance;
}

+ (void)configure:(NSString *)apiKey {
    [DataManager sharedInstance].apiKey = apiKey;
}

- (instancetype)init {
    return [self initWithConfiguration:@{}];
}

- (instancetype)initWithConfiguration:(NSDictionary *)config {
    self = [super init];
    if (self) {
        _networkClient = [[NetworkClient alloc] init];
        _isConnected = NO;
        
        // Configure with provided config
        [self setupWithConfiguration:config];
    }
    return self;
}

- (void)fetchDataWithCompletion:(void (^)(NSData *data, NSError *error))completion {
    if (!self.isConnected) {
        NSError *error = [NSError errorWithDomain:@"DataManagerError" 
                                             code:1001 
                                         userInfo:@{NSLocalizedDescriptionKey: @"Not connected"}];
        completion(nil, error);
        return;
    }
    
    [self.networkClient requestDataWithCompletion:completion];
}

- (BOOL)validateData:(NSData *)data {
    return data != nil && data.length > 0;
}

- (void)setupWithConfiguration:(NSDictionary *)config {
    // Private method for internal setup
    self.isConnected = YES;
}

@end