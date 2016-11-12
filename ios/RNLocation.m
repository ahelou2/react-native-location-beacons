#import <CoreLocation/CoreLocation.h>

#import "RCTBridge.h"
#import "RCTConvert.h"
#import "RCTEventDispatcher.h"

#import "RNLocation.h"

@interface RNLocation() <CLLocationManagerDelegate>

@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) NSUUID *beaconUUID;
@property (strong, nonatomic) NSString *beaconIdentifier;
@property (strong, nonatomic) CLBeaconRegion *region;

@end

@implementation RNLocation

RCT_EXPORT_MODULE()

@synthesize bridge = _bridge;

#pragma mark Initialization

- (instancetype)init
{
    if (self = [super init]) {
        self.locationManager = [[CLLocationManager alloc] init];

        self.locationManager.delegate = self;

        self.locationManager.distanceFilter = kCLDistanceFilterNone;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;

        self.locationManager.pausesLocationUpdatesAutomatically = NO;
        // default values
        self.beaconUUID = [[NSUUID alloc] initWithUUIDString:@"66622e6d-652f-40ca-9e6f-6f7166616365"];
        self.beaconIdentifier = @"com.ar.location";
        self.region = [[CLBeaconRegion alloc] initWithProximityUUID:self.beaconUUID identifier:self.beaconIdentifier];
        

    }

    return self;
}

#pragma mark

RCT_EXPORT_METHOD(requestAlwaysAuthorization)
{
    NSLog(@"react-native-location: requestAlwaysAuthorization");
    [self.locationManager requestAlwaysAuthorization];
}

RCT_EXPORT_METHOD(requestWhenInUseAuthorization)
{
    NSLog(@"react-native-location: requestWhenInUseAuthorization");
    [self.locationManager requestWhenInUseAuthorization];
}

RCT_EXPORT_METHOD(getAuthorizationStatus:(RCTResponseSenderBlock)callback)
{
    callback(@[[self nameForAuthorizationStatus:[CLLocationManager authorizationStatus]]]);
}

RCT_EXPORT_METHOD(setDesiredAccuracy:(double) accuracy)
{
    self.locationManager.desiredAccuracy = accuracy;
}

RCT_EXPORT_METHOD(setDistanceFilter:(double) distance)
{
    self.locationManager.distanceFilter = distance;
}

RCT_EXPORT_METHOD(setAllowsBackgroundLocationUpdates:(BOOL) enabled)
{
    self.locationManager.allowsBackgroundLocationUpdates = enabled;
}

RCT_EXPORT_METHOD(setBeaconUUID:(NSString *) beaconUUID identifier:(NSString *) identifier)
{
    if (beaconUUID) {
        self.beaconUUID = [[NSUUID alloc] initWithUUIDString:beaconUUID];
    }
    if (identifier) {
        self.beaconIdentifier = identifier;
    }
    self.region = [[CLBeaconRegion alloc] initWithProximityUUID:self.beaconUUID identifier:self.beaconIdentifier];
}

RCT_EXPORT_METHOD(startMonitoringSignificantLocationChanges)
{
    NSLog(@"react-native-location: startMonitoringSignificantLocationChanges");
    [self.locationManager startMonitoringSignificantLocationChanges];
}

RCT_EXPORT_METHOD(startUpdatingLocation)
{
    [self.locationManager startUpdatingLocation];
}

RCT_EXPORT_METHOD(startUpdatingHeading)
{
    [self.locationManager startUpdatingHeading];
}

RCT_EXPORT_METHOD(startRangingBeacons)
{
    [self.locationManager startRangingBeaconsInRegion:self.region];
}

RCT_EXPORT_METHOD(stopMonitoringSignificantLocationChanges)
{
    [self.locationManager stopMonitoringSignificantLocationChanges];
}

RCT_EXPORT_METHOD(stopUpdatingLocation)
{
    [self.locationManager stopUpdatingLocation];
}

RCT_EXPORT_METHOD(stopUpdatingHeading)
{
    [self.locationManager stopUpdatingHeading];
}

RCT_EXPORT_METHOD(stopRangingBeaconsInRegion)
{
    [self.locationManager stopRangingBeaconsInRegion:self.region];
}


-(NSString *)nameForAuthorizationStatus:(CLAuthorizationStatus)authorizationStatus
{
    switch (authorizationStatus) {
        case kCLAuthorizationStatusAuthorizedAlways:
            NSLog(@"Authorization Status: authorizedAlways");
            return @"authorizedAlways";

        case kCLAuthorizationStatusAuthorizedWhenInUse:
            NSLog(@"Authorization Status: authorizedWhenInUse");
            return @"authorizedWhenInUse";

        case kCLAuthorizationStatusDenied:
            NSLog(@"Authorization Status: denied");
            return @"denied";

        case kCLAuthorizationStatusNotDetermined:
            NSLog(@"Authorization Status: notDetermined");
            return @"notDetermined";

        case kCLAuthorizationStatusRestricted:
            NSLog(@"Authorization Status: restricted");
            return @"restricted";
    }
}

-(void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    NSString *statusName = [self nameForAuthorizationStatus:status];
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"authorizationStatusDidChange" body:statusName];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"Location manager failed: %@", error);
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading {
  if (newHeading.headingAccuracy < 0)
    return;

  // Use the true heading if it is valid.
  CLLocationDirection heading = ((newHeading.trueHeading > 0) ?
    newHeading.trueHeading : newHeading.magneticHeading);

  NSDictionary *headingEvent = @{
    @"heading": @(heading)
  };

  NSLog(@"heading: %f", heading);
  [self.bridge.eventDispatcher sendDeviceEventWithName:@"headingUpdated" body:headingEvent];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    CLLocation *location = [locations lastObject];
    NSDictionary *locationEvent = @{
        @"coords": @{
            @"latitude": @(location.coordinate.latitude),
            @"longitude": @(location.coordinate.longitude),
            @"altitude": @(location.altitude),
            @"accuracy": @(location.horizontalAccuracy),
            @"altitudeAccuracy": @(location.verticalAccuracy),
            @"course": @(location.course),
            @"speed": @(location.speed),
        },
        @"timestamp": @([location.timestamp timeIntervalSince1970] * 1000) // in ms
    };

    NSLog(@"%@: lat: %f, long: %f, altitude: %f", location.timestamp, location.coordinate.latitude, location.coordinate.longitude, location.altitude);
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"locationUpdated" body:locationEvent];
}

- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region
{
    /*
     CoreLocation will call this delegate method at 1 Hz with updated range information.
     Beacons will be categorized and displayed by proximity.  A beacon can belong to multiple
     regions.  It will be displayed multiple times if that is the case.  If that is not desired,
     use a set instead of an array.
     */
    
    if (!beacons || [beacons count] == 0) {
        [NSException exceptionWithName:NSInternalInconsistencyException reason:@"" userInfo:@{}];
    }
    
    NSMutableArray *beaconsData = [NSMutableArray arrayWithCapacity:[beacons count]];
    for (CLBeacon *beacon in beacons) {
        
        if (!beacon) {
            [NSException exceptionWithName:NSInternalInconsistencyException reason:@"" userInfo:@{}];
        }
        
        NSString *proximityStr;
        if (beacon.proximity == CLProximityUnknown) {
            proximityStr = @"CLProximityUnknown";
        } else if (beacon.proximity == CLProximityFar) {
            proximityStr = @"CLProximityFar";
        } else if (beacon.proximity == CLProximityNear) {
            proximityStr = @"CLProximityNear";
        } else if (beacon.proximity == CLProximityImmediate) {
            proximityStr = @"CLProximityImmediate";
        } else {
            @throw @"unknown CLProximity value";
        }
        
        [beaconsData addObject:
        @{
          @"uuid": [beacon.proximityUUID UUIDString],
          @"major": [beacon major],
          @"minor": [beacon minor],
          @"accuracy": @([beacon accuracy]),
          @"rssi": @([beacon rssi]),
          }
         ];
    }
    
    
    NSLog(@"beacons = %@", beaconsData);
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"beaconsUpdated" body:beaconsData];
}


@end
