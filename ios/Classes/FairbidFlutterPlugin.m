#import "FairbidFlutterPlugin.h"
#import <FairBidSDK/FYBPluginOptions.h>


@implementation AdapterStartedStreamHandler

 FlutterEventSink sink;
    
- (FlutterError * _Nullable)onCancelWithArguments:(id _Nullable)arguments {
    sink = nil;
    return nil;
}

- (FlutterError * _Nullable)onListenWithArguments:(id _Nullable)arguments eventSink:(nonnull FlutterEventSink)events {
    sink = events;
    return nil;
}

- (void)sendAdapterStartEvent:(NSString *)name version:(NSString *)version message: ( NSString* _Nullable) message {
    if (sink != nil) {
        NSMutableDictionary *dataCollector = [@{@"name": name, @"version": version} mutableCopy];
        if (message != nil){
            [dataCollector setValue:message forKey:@"message"];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            sink(dataCollector);
        });
    }
}

@end

@implementation FairbidFlutterPlugin

static NSString *const  PLACEMENT_KEY = @"placement";
static NSString *const  AD_TYPE_KEY = @"adType";
static NSString *const  EXTRA_OPTIONS_TYPE_KEY = @"extraOptions";
static NSString *const  INTERSTITIAL_KEY = @"interstitial";
static NSString *const  REWARDED_KEY = @"rewarded";
static NSString *const  BANNER_KEY = @"banner";

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    FlutterMethodChannel *channel = [FlutterMethodChannel
        methodChannelWithName:@"pl.ukaszapps.fairbid_flutter"
        binaryMessenger:[registrar messenger]];
    FairbidFlutterPlugin *instance = [[FairbidFlutterPlugin alloc] initWithRegistrar:registrar];

    [registrar addMethodCallDelegate:instance channel:channel];
}

NSObject<FlutterPluginRegistrar>        *_registrar;
AdapterStartedStreamHandler             *_adapterStartStreamHandler;
EventProducingRewardedDelegateImpl      *_rewardedDelegate;
EventProducingInterstitialDelegateImpl  *_interstitialDelegate;
BannerDelegateImpl                      *_bannerDelegate;

- (id)initWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    _registrar = registrar;
    
    FlutterEventChannel *adapterEventChannel = [FlutterEventChannel eventChannelWithName:@"pl.ukaszapps.fairbid_flutter:adapterEvents" binaryMessenger:[_registrar messenger]];
    _adapterStartStreamHandler = [[AdapterStartedStreamHandler alloc] init];
    [adapterEventChannel setStreamHandler:_adapterStartStreamHandler];
    return self;
}
- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    NSDictionary *arguments = [call arguments];

    NSLog(@"[FB_Flutter] %@ method called", call.method);

    if ([@"getPlatformVersion" isEqualToString:call.method]) {
        result(FairBid.version);
    } else if ([@"startSdk" isEqualToString:call.method]) {
        [self startSdkAndInitListeners:arguments result:result];
    } else if ([@"isAvailable" isEqualToString:call.method]) {
        [self isAvailable:arguments result:result];
    } else if ([@"request" isEqualToString:call.method]) {
        [self request:arguments result:result];
    } else if ([@"show" isEqualToString:call.method]) {
        [self show:arguments result:result];
    } else if ([@"showTestSuite" isEqualToString:call.method]) {
        [self showTestSuite];
    } else if ([@"updateGDPR" isEqualToString:call.method]) {
        [self updateGDPR:arguments result:result];
    } else if ([@"clearGDPR" isEqualToString:call.method]) {
        [self clearGDPR:result];
    } else if ([@"getUserData" isEqualToString:call.method]) {
        [self getUserData:result];
    } else if ([@"updateUserData" isEqualToString:call.method]) {
        [self updateUser:arguments result:result];
    } else if ([@"loadBanner" isEqualToString:call.method]) {
        [self loadBanner:arguments result:result];
    } else if ([@"destroyBanner" isEqualToString:call.method]) {
        [self destroyBanner:arguments result:result];
    }  else if ([@"showAlignedBanner" isEqualToString:call.method]) {
        [self showAlignedBanner:arguments result:result];
    } else if ([@"destroyAlignedBanner" isEqualToString:call.method]) {
        [self destroyAlignedBanner:arguments result:result];
    } else if ([@"getImpressionDepth" isEqualToString:call.method]) {
        [self getImpressionDepth:arguments result:result];
    } else if ([@"updateCCPA" isEqualToString:call.method]) {
        [self updateCCPAString:arguments result:result];
    } else if ([@"clearCCPA" isEqualToString:call.method]) {
        [self clearCCPAString:result];
    } else if ([@"setMuted" isEqualToString:call.method]) {
        [self setMuted:arguments result:result];
    } else if ([@"changeAutoRequesting" isEqualToString:call.method]) {
        [self changeAutoRequesting:arguments result:result];
    } else if ([@"getImpressionData" isEqualToString:call.method]) {
        [self getImpressionData:arguments result:result];
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)startSdkAndInitListeners:(NSDictionary *)arguments result:(FlutterResult)result {
    NSString *publisherId = arguments[@"publisherId"];
    
    if ([FairBid isStarted]) {
        result([NSNumber numberWithBool:YES]);
        return;
    }

    NSNumber    *autoRequestingAttr = arguments[@"autoRequesting"];
    BOOL        autoRequesting = autoRequestingAttr == nil || [autoRequestingAttr boolValue];

    NSNumber    *loggingLevelAttr = arguments[@"loggingLevel"];
    FYBLoggingLevel loggingLevel = FYBLoggingLevelSilent;
    if (loggingLevelAttr) {
        switch ([loggingLevelAttr intValue]) {
            case 0:
                loggingLevel = FYBLoggingLevelVerbose;
                break;
            case 1:
                loggingLevel = FYBLoggingLevelInfo;
                break;
            case 2:
                loggingLevel = FYBLoggingLevelError;
                break;
            default:
                break;
        }
    }
    
    // send plugin version
    NSString *pluginVersion = arguments[@"pluginVersion"];
    FYBPluginOptions *pluginOptions = [[FYBPluginOptions alloc] init];
    pluginOptions.pluginFramework = FYBPluginFrameworkFlutter;
    pluginOptions.pluginSdkVersion = pluginVersion;
   
    FYBStartOptions *options = [[FYBStartOptions alloc] init];

    options.logLevel = loggingLevel;
    options.autoRequestingEnabled = autoRequesting;
    
    options.pluginOptions = pluginOptions;
    
    FairBid.delegate = self;
    
    [FairBid startWithAppId:publisherId options:options];

    // registering listeners
    _interstitialDelegate = [[EventProducingInterstitialDelegateImpl alloc] init];
    _rewardedDelegate = [[EventProducingRewardedDelegateImpl alloc] init];
    _bannerDelegate = [[BannerDelegateImpl alloc] initWith: [_registrar messenger]];

    FYBRewarded.delegate = _rewardedDelegate;
    FYBInterstitial.delegate = _interstitialDelegate;
    FYBBanner.delegate = _bannerDelegate;
    
    [_registrar registerViewFactory:_bannerDelegate withId: @"bannerView"];

    FlutterEventChannel *eventChannel = [FlutterEventChannel eventChannelWithName:@"pl.ukaszapps.fairbid_flutter:events" binaryMessenger:[_registrar messenger]];

    [eventChannel setStreamHandler:self];

    result([NSNumber numberWithBool:YES]);
}

- (void)isAvailable:(NSDictionary *)arguments result:(FlutterResult)result {
    NSString    *placement = arguments[PLACEMENT_KEY];
    NSString    *type = arguments[AD_TYPE_KEY];

    if ([INTERSTITIAL_KEY isEqualToString:type]) {
        result([NSNumber numberWithBool:[FYBInterstitial isAvailable:placement]]);
    } else if ([REWARDED_KEY isEqualToString:type]) {
        result([NSNumber numberWithBool:[FYBRewarded isAvailable:placement]]);
    } else {
        result([NSNumber numberWithBool:NO]);
    }
}

- (void)request:(NSDictionary *)arguments result:(FlutterResult)result {
    NSString    *placement = arguments[PLACEMENT_KEY];
    NSString    *type = arguments[AD_TYPE_KEY];

    if ([INTERSTITIAL_KEY isEqualToString:type]) {
        [FYBInterstitial request:placement];
        result([NSNumber numberWithBool:YES]);
    } else if ([REWARDED_KEY isEqualToString:type]) {
        [FYBRewarded request:placement];
        result([NSNumber numberWithBool:YES]);
    } else {
        result([NSNumber numberWithBool:NO]);
    }
}

- (void)show:(NSDictionary *)arguments result:(FlutterResult)result {
    NSString    *placement = arguments[PLACEMENT_KEY];
    NSString    *type = arguments[AD_TYPE_KEY];
    NSDictionary *extraOptions = arguments[EXTRA_OPTIONS_TYPE_KEY];

    if ([INTERSTITIAL_KEY isEqualToString:type]) {
        if (extraOptions && ![extraOptions isEqual:[NSNull null]]){
            FYBShowOptions *showOptions = [FYBShowOptions new];
            showOptions.customParameters = extraOptions;
            [FYBInterstitial show:placement options:showOptions];
        } else {
            [FYBInterstitial show:placement];
        }
        result([NSNumber numberWithBool:YES]);
    } else if ([REWARDED_KEY isEqualToString:type]) {
        if (extraOptions && ![extraOptions isEqual:[NSNull null]]){
            FYBShowOptions *showOptions = [FYBShowOptions new];
            showOptions.customParameters = extraOptions;
            [FYBRewarded show:placement options:showOptions];
        } else {
            [FYBRewarded show:placement];
        }
        result([NSNumber numberWithBool:YES]);
    } else {
        result([NSNumber numberWithBool:NO]);
    }
}

- (void)showTestSuite {
    [FairBid presentTestSuite];
}

- (void)updateGDPR:(NSDictionary *)arguments result:(FlutterResult)result {
    NSNumber        *consentGrantedArg = arguments[@"grantConsent"];
    if (consentGrantedArg != nil){
        BOOL        consentGranted = [consentGrantedArg boolValue];
        [FairBid user].GDPRConsent = consentGranted;
    }
    NSString        *consentString = arguments[@"consentString"];

    [FairBid user].GDPRConsentString = consentString;
    result(nil);
}

- (void)clearGDPR:(FlutterResult)result {
    [[FairBid user] clearGDPRConsent];
    result(nil);
}

- (void)updateCCPAString:(NSDictionary *)arguments result:(FlutterResult) result {
    NSString        *ccpaString = arguments[@"consentString"];
    [FairBid user].IABUSPrivacyString = ccpaString;
    result(nil);
}

- (void)clearCCPAString:(FlutterResult)result {
    [[FairBid user] clearIABUSPrivacyString];
    result(nil);
}

- (void)setMuted:(NSDictionary *)arguments result:(FlutterResult) result {
    NSNumber        *muteArg = arguments[@"mute"];
    BOOL            mute = muteArg != nil && [muteArg boolValue];
    [FairBid settings].muted = mute;
    result(nil);
}


- (void)getUserData:(FlutterResult)result {
    FYBUserInfo *user = [FairBid user];

    NSString *genderCode = @"u";

    switch ([user gender]) {
        case FYBGenderMale:
            genderCode = @"m";
            break;

        case FYBGenderFemale:
            genderCode = @"f";
            break;

        case FYBGenderOther:
            genderCode = @"o";
            break;

        default:
            break;
    }

    NSDictionary *basicUserData = @{
        @"gender": genderCode
    };
    NSMutableDictionary *userData = [basicUserData mutableCopy];

    NSDate *birthday = [user birthDate];

    if (birthday != nil) {
        NSCalendar      *calendar = [NSCalendar currentCalendar];
        NSDictionary    *birthdayData = @{
            @"year" : [NSNumber numberWithInteger:[calendar component:NSCalendarUnitYear fromDate:birthday]],
            @"month": [NSNumber numberWithInteger:[calendar component:NSCalendarUnitMonth fromDate:birthday]],
            @"day":[NSNumber numberWithInteger:[calendar component:NSCalendarUnitDay fromDate:birthday]]
        };
        [userData setValue:birthdayData forKey:@"birthday"];
    }

    CLLocation *location = [user location];

    if (location != nil) {
        NSDictionary *locationData = @{
            @"latitude":[NSNumber numberWithDouble:[location coordinate].latitude],
            @"longitude":[NSNumber numberWithDouble:[location coordinate].longitude]
        };
        [userData setValue:locationData forKey:@"location"];
    }
    
    [userData setValue:[user userId] forKey:@"id"];

    result(userData);
}

- (void)updateUser:(NSDictionary *)arguments result:(FlutterResult)result {
    [self updateUserGender:arguments[@"gender"]];
    [self updateUserBirthday:arguments[@"birthday"]];
    [self updateUserLocation:arguments[@"location"]];
    [self updateUserId:arguments[@"id"]];
    result(nil);
}

- (void)updateUserId:(nullable NSString *)identifier {
    [[FairBid user] setUserId:identifier];
}

- (void)updateUserLocation:location {
    if (location != nil) {
        NSDictionary    *locationData = location;
        NSNumber        *latitude = locationData[@"latitude"];
        NSNumber        *longitude = locationData[@"longitude"];
        [[FairBid user] setLocation:[[CLLocation alloc] initWithLatitude:[latitude doubleValue] longitude:[longitude doubleValue]]];
    } else {
        [[FairBid user] setLocation:nil];
    }
}

- (void)updateUserBirthday:(id _Nullable)birthday {
    if (birthday != nil) {
        NSDictionary        *birthdayData = birthday;
        NSNumber            *year = birthdayData[@"year"];
        NSNumber            *month = birthdayData[@"month"];
        NSNumber            *day = birthdayData[@"day"];
        NSCalendar          *gregorian = [NSCalendar currentCalendar];
        NSDateComponents    *comps = [[NSDateComponents alloc] init];
        [comps setYear:[year integerValue]];
        [comps setMonth:[month integerValue]];
        [comps setDay:[day integerValue]];
        NSDate *date = [gregorian dateFromComponents:comps];
        [[FairBid user] setBirthDate:date];
    } else {
        [[FairBid user] setBirthDate:nil];
    }
}

- (void)updateUserGender:(id _Nullable)gender {
    if (gender != nil) {
        NSString *genderCode = gender;

        if ([@"m" isEqualToString:genderCode]) {
            [[FairBid user] setGender:FYBGenderMale];
        } else if ([@"f" isEqualToString:genderCode]) {
            [[FairBid user] setGender:FYBGenderFemale];
        } else if ([@"o" isEqualToString:genderCode]) {
            [[FairBid user] setGender:FYBGenderOther];
        } else {
            [[FairBid user] setGender:FYBGenderUnknown];
        }
    } else {
        [[FairBid user] setGender:FYBGenderUnknown];
    }
}

- (void)loadBanner:(NSDictionary *)arguments result:(FlutterResult)result {
    NSString *placement = arguments[@"placement"];
    NSNumber *width = arguments[@"width"];
    NSNumber *height = arguments[@"height"];
    
    [_bannerDelegate loadBanner:placement width:width height:height andResult: result];
    
}

- (void)destroyBanner:(NSDictionary *)arguments result:(FlutterResult)result {
    NSString *placement = arguments[@"placement"];
    
    [_bannerDelegate destroyBanner:placement];
    result([NSNumber numberWithBool:YES]);
}

- (void)showAlignedBanner:(NSDictionary *)arguments result:(FlutterResult)result {
    NSString *placement = arguments[@"placement"];
    NSString *alignment = arguments[@"alignment"];
    
    FYBBannerOptions *bannerOptions = [[FYBBannerOptions alloc] init];
    bannerOptions.placementId = placement;
    FYBBannerAdViewPosition position = FYBBannerAdViewPositionTop;
    if ([@"bottom" isEqualToString:alignment]){
        position =FYBBannerAdViewPositionBottom;
    }
    [FYBBanner showBannerInView: nil position:position options:bannerOptions];
    result([NSNumber numberWithBool:YES]);
}

- (void)destroyAlignedBanner:(NSDictionary *)arguments result:(FlutterResult)result {
    [self destroyBanner:arguments result:result];
}
- (void)getImpressionDepth:(NSDictionary *)arguments result:(FlutterResult)result {
    NSString    *type = arguments[AD_TYPE_KEY];

    if ([INTERSTITIAL_KEY isEqualToString:type]) {
        result([NSNumber numberWithUnsignedLong: FYBInterstitial.impressionDepth]);
    } else if ([REWARDED_KEY isEqualToString:type]) {
        result([NSNumber numberWithUnsignedLong: FYBRewarded.impressionDepth]);
    } else if ([BANNER_KEY isEqualToString:type]) {
        result([NSNumber numberWithUnsignedLong: FYBBanner.impressionDepth]);
    }
}

- (void) changeAutoRequesting:(NSDictionary *)arguments result:(FlutterResult) result {
    NSNumber        *enableVal = arguments[@"enable"];
    BOOL            enable = enableVal != nil && [enableVal boolValue];
    NSString        *type = arguments[AD_TYPE_KEY];
    NSString        *placement = arguments[@"placement"];
    if ([INTERSTITIAL_KEY isEqualToString:type]) {
        if (enable) {
            [FYBInterstitial enableAutoRequesting:placement];
        } else {
            [FYBInterstitial disableAutoRequesting:placement];
        }
        result([NSNumber numberWithBool:enable]);
    } else if ([REWARDED_KEY isEqualToString:type]) {
        if (enable) {
            [FYBRewarded enableAutoRequesting:placement];
        } else {
            [FYBRewarded disableAutoRequesting:placement];
        }
        result([NSNumber numberWithBool:enable]);
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (void) getImpressionData:(NSDictionary *)arguments result:(FlutterResult) result {
    NSString        *type = arguments[AD_TYPE_KEY];
    NSString        *placement = arguments[@"placement"];
    if ([INTERSTITIAL_KEY isEqualToString:type]) {
        FYBImpressionData *impressionData = [FYBInterstitial impressionData:placement];
        result(impressionDataAsDictionary(impressionData));
    } else if ([REWARDED_KEY isEqualToString:type]) {
        FYBImpressionData *impressionData = [FYBRewarded impressionData:placement];
        result(impressionDataAsDictionary(impressionData));
    } else {
        result(FlutterMethodNotImplemented);
    }
}

static NSDictionary *impressionDataAsDictionary(FYBImpressionData *impressionData) {
    NSString *priceAccuracy = @"undisclosed";
    switch (impressionData.priceAccuracy) {
        case FYBImpressionDataPriceAccuracyPredicted:
            priceAccuracy = @"predicted";
            break;
        case FYBImpressionDataPriceAccuracyProgrammatic:
            priceAccuracy = @"programmatic";
        default:
            break;
    }
    NSMutableDictionary *dataCollector = [@{@"priceAccuracy": priceAccuracy} mutableCopy];
    if (impressionData.netPayout){
        [dataCollector setValue:impressionData.netPayout forKey:@"netPayout"];
    }
    if (impressionData.impressionId){
        [dataCollector setValue:impressionData.impressionId forKey:@"impressionId"];
    }
    if (impressionData.advertiserDomain){
        [dataCollector setValue:impressionData.advertiserDomain forKey:@"advertiserDomain"];
    }
    if (impressionData.campaignId){
        [dataCollector setValue:impressionData.campaignId forKey:@"campaignId"];
    }
    if (impressionData.countryCode){
        [dataCollector setValue:impressionData.countryCode forKey:@"countryCode"];
    }
    if (impressionData.creativeId){
        [dataCollector setValue:impressionData.creativeId forKey:@"creativeId"];
    }
    if (impressionData.currency){
        [dataCollector setValue:impressionData.currency forKey:@"currency"];
    }
    if (impressionData.demandSource){
        [dataCollector setValue:impressionData.demandSource forKey:@"demandSource"];
    }
    if (impressionData.networkInstanceId){
        [dataCollector setValue:impressionData.networkInstanceId forKey:@"networkInstanceId"];
    }
    if (impressionData.renderingSDK){
        [dataCollector setValue:impressionData.renderingSDK forKey:@"renderingSdk"];
    }
    if (impressionData.renderingSDKVersion){
        [dataCollector setValue:impressionData.renderingSDKVersion forKey:@"renderingSdkVersion"];
    }
    if (impressionData.variantId){
        [dataCollector setValue:impressionData.variantId forKey:@"variantId"];
    }
    [dataCollector setValue:[NSNumber numberWithUnsignedLong: impressionData.impressionDepth] forKey:@"impressionDepth"];
    return dataCollector;
}

// prototocol FlutterStreamHandler
- (FlutterError *_Nullable) onListenWithArguments   :(id _Nullable)arguments
                            eventSink               :(nonnull FlutterEventSink)events {
    EventSender sender = ^(NSString *type, NSString *placement, NSString *eventName, FYBImpressionData *impressionData, NSArray *extras) {
        
        NSLog(@"[FB_Flutter] Event %@, %@, %@, %@", type, placement, eventName, impressionData);
        NSObject *impressionDataMap = [NSNull null];
        if (impressionData){
            impressionDataMap = impressionDataAsDictionary(impressionData);
            
        }
        NSArray *eventData = @[type, placement, eventName, impressionDataMap];
        
        if (extras){
            eventData = [eventData arrayByAddingObjectsFromArray:extras];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            events(eventData);
        });
    };

    NSLog(@"[FB_Flutter] onListenWithArguments -> %@", events);
    [_interstitialDelegate setEventSender:sender];
    [_rewardedDelegate setEventSender:sender];
    [_bannerDelegate setEventSender:sender];
    return nil;
}

- (FlutterError *_Nullable)onCancelWithArguments:(id _Nullable)arguments {
    [_interstitialDelegate setEventSender:nil];
    [_rewardedDelegate setEventSender:nil];
    [_bannerDelegate setEventSender:nil];
    return nil;
}

// end of protocol FlutterStreamHandler

// protocol FairBidDelegate
- (void)networkStarted:(FYBMediatedNetwork)network {
    [_adapterStartStreamHandler sendAdapterStartEvent: [self mediatedNetworkToString: network] version: @"unknown" message: nil];
}
- (void)network:(FYBMediatedNetwork)network failedToStartWithError:(NSError *)error{
    [_adapterStartStreamHandler sendAdapterStartEvent: [self mediatedNetworkToString: network] version: @"unknown" message: [error localizedDescription]];
}

- (NSString*) mediatedNetworkToString: (FYBMediatedNetwork) network{
    switch (network) {
        case FYBMediatedNetworkSnap:
            return @"Snap";
        case FYBMediatedNetworkOgury:
            return @"Ogury";
        case FYBMediatedNetworkPangle:
            return @"Pangle";
        case FYBMediatedNetworkTapjoy:
            return @"Tapjoy";
        case FYBMediatedNetworkVungle:
            return @"Vungle";
        case FYBMediatedNetworkVerizon:
            return @"Verizon";
        case FYBMediatedNetworkFacebook:
            return @"Facebook";
        case FYBMediatedNetworkMintegral:
            return @"Mintegral";
        case FYBMediatedNetworkChartboost:
            return @"Chartboost";
        case FYBMediatedNetworkAdMob:
            return @"AdMob";
        case FYBMediatedNetworkHyprMX:
            return @"HyprMX";
        case FYBMediatedNetworkInMobi:
            return @"InMobi";
        case FYBMediatedNetworkAdColony:
            return @"AdColony";
        case FYBMediatedNetworkAppLovin:
            return @"AppLovin";
        case FYBMediatedNetworkUnityAds:
            return @"UnityAds";
        case FYBMediatedNetworkIronSource:
            return @"IronSource";
        case FYBMediatedNetworkMyTarget:
            return @"MyTarget";
            
        default:
            return @"unknown";
    }
}
// end of protocol FairBidDelegate
@end

