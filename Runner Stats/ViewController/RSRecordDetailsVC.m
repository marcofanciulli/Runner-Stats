//
//  RSRecordDetailsVC.m
//  RunningStats
//
//  Created by Mr. Who on 1/1/14.
//  Copyright (c) 2014 hk. All rights reserved.
//

#import "RSRecordDetailsVC.h"
#import "RSRecordManager.h"
#import "PNChart.h"
#import "JBChartInformationView.h"
#import "JBChartHeaderView.h"
#import "JBLineChartFooterView.h"
#import "RSStatsVC.h"

#define NUMBER_OF_XY_POINTS 60
#define NUMBER_OF_SECTION_POINTS 25

// Numerics
CGFloat const kJBLineChartViewControllerChartHeight = 250.0f;
CGFloat const kJBLineChartViewControllerChartHeaderHeight = 70.0f;
CGFloat const kJBLineChartViewControllerChartHeaderPadding = 10.0f;
CGFloat const kJBLineChartViewControllerChartFooterHeight = 20.0f;

@interface RSRecordDetailsVC ()
@property (strong, nonatomic) RSRecordManager *recordManager;
@property (strong, nonatomic) JBChartHeaderView *headerView;
@property (strong, nonatomic) JBLineChartView *lineChart;
@property (strong, nonatomic) JBChartInformationView *infoView;
@property (strong, nonatomic) NSString *record;
@property (strong, nonatomic) NSString *recordPath;
@property (strong, nonatomic) NSArray *recordData;
// flagPoint is for marking every kilometer or mile covered
@property (assign, nonatomic) NSUInteger flagPoint;
@property (assign, nonatomic) CLLocationSpeed maxSpeed;
// iAD banner
@property (strong, nonatomic) ADBannerView *iAd;
@end

@implementation RSRecordDetailsVC

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        //_lineChart = [[PNLineChart alloc] initWithFrame:CGRectMake(0, 235.0, SCREEN_WIDTH, 200.0)];
        _recordManager = [[RSRecordManager alloc] init];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    self.flagPoint = 1000;
    [self configureDataSource];
    if ([self.recordData count] < 1) {
        return;
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    // lineChart
    [self configureLineChart];
    // headerView
    [self configureHeaderView];
    // footerView
    [self configureFooterView];
    // informationView
    [self configureInfoView];
    // setup iAd banner
    [self setupADBanner];
    
    [self.view addSubview:self.lineChart];
    [self.lineChart reloadData];
    [self.lineChart setState:JBChartViewStateCollapsed];
    // Disable the former page view
    RSStatsVC *parentVC = (RSStatsVC *)self.navigationController.parentViewController;
    parentVC.pageControl.hidden = YES;
    parentVC.currentStatsView.scrollEnabled = NO;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.lineChart setState:JBChartViewStateExpanded animated:YES];
}

- (void)configureDataSource
{
    NSArray *dataArray = [self.recordManager readRecordDetailsByPath:self.recordPath] ;
    if ([dataArray count] <= 1) {
        NSLog(@"!? path:%@", self.recordPath);
        return;
    }
    // allow at most 50 points to be drawn
    CLLocationDistance SMALLEST_GAP = [[[dataArray objectAtIndex:[dataArray count]-2] objectAtIndex:1] doubleValue] / NUMBER_OF_XY_POINTS;
    SMALLEST_GAP = MAX(SMALLEST_GAP, 30.0);
    
    NSMutableArray *tempRecordData = [[NSMutableArray alloc] init];
    CLLocationDistance distanceFilter = 0;
    CLLocationDistance currentDistance = 0;
    self.maxSpeed = 0;
    for (int i=0; i < [dataArray count]-1; ++i) {
        currentDistance = [[dataArray[i] objectAtIndex:1] doubleValue];
        if ((currentDistance - distanceFilter) > SMALLEST_GAP) {
            distanceFilter = currentDistance;
            [tempRecordData addObject:dataArray[i]];
            self.maxSpeed = MAX(self.maxSpeed, [[dataArray[i] lastObject] doubleValue]);
        }
    }
    // add the last line of data
    if ((currentDistance - distanceFilter) != 0) {
        [tempRecordData addObject:[dataArray objectAtIndex:[dataArray count]-2]];
    }
    self.recordData = [NSArray arrayWithArray:tempRecordData];
}

- (void)configureLineChart
{
    if (!self.lineChart) {
        self.lineChart = [[JBLineChartView alloc] initWithFrame:CGRectMake(kJBNumericDefaultPadding, 50, self.view.bounds.size.width - (kJBNumericDefaultPadding * 2), kJBLineChartViewControllerChartHeight)];
    }
    self.lineChart.delegate = self;
    self.lineChart.dataSource = self;
}

- (void)configureHeaderView
{
    if (!self.headerView) {
        self.headerView = [[JBChartHeaderView alloc] initWithFrame:CGRectMake(kJBNumericDefaultPadding, ceil(self.view.bounds.size.height * 0.5) - ceil(kJBLineChartViewControllerChartHeaderHeight * 0.5), self.view.bounds.size.width - (kJBNumericDefaultPadding * 2), kJBLineChartViewControllerChartHeaderHeight)];
    }
    
    self.headerView.titleLabel.text = [self getHeaderTitleFromRecord:self.record];
    self.headerView.titleLabel.textColor = kJBColorLineChartHeader;
    self.headerView.titleLabel.shadowColor = [UIColor colorWithWhite:1.0 alpha:0.25];
    self.headerView.titleLabel.shadowOffset = CGSizeMake(0, 1);
    self.headerView.subtitleLabel.text = [NSLocalizedString(@"Max Speed", nil) stringByAppendingString:[[NSString stringWithFormat:@": %.1f ", self.maxSpeed * SECONDS_OF_HOUR/RS_UNIT] stringByAppendingString:RS_SPEED_UNIT_STRING]];
    self.headerView.subtitleLabel.textColor = kJBColorLineChartHeader;
    self.headerView.subtitleLabel.shadowColor = [UIColor colorWithWhite:1.0 alpha:0.25];
    self.headerView.subtitleLabel.shadowOffset = CGSizeMake(0, 1);
    self.headerView.separatorColor = kJBColorLineChartHeaderSeparatorColor;
    self.lineChart.headerView = self.headerView;
}

- (void)configureFooterView
{
    JBLineChartFooterView *footerView = [[JBLineChartFooterView alloc] initWithFrame:CGRectMake(kJBNumericDefaultPadding, ceil(self.view.bounds.size.height * 0.5) - ceil(kJBLineChartViewControllerChartFooterHeight * 0.5), self.view.bounds.size.width - (kJBNumericDefaultPadding * 2), kJBLineChartViewControllerChartFooterHeight)];
    footerView.leftLabel.text = [NSString stringWithFormat:@"%d", 0];
    footerView.leftLabel.textColor = [UIColor blackColor];
    CLLocationDistance distance = [[[self.recordData lastObject] objectAtIndex:1] doubleValue];
    footerView.rightLabel.text = [[NSString stringWithFormat:@"%.2f ", distance/RS_UNIT] stringByAppendingString:RS_DISTANCE_UNIT_STRING];
    footerView.rightLabel.textColor = [UIColor blackColor];
    footerView.sectionCount = NUMBER_OF_SECTION_POINTS;
    footerView.footerSeparatorColor = [UIColor blackColor];
    self.lineChart.footerView = footerView;
}

- (void)configureInfoView
{
    self.infoView = [[JBChartInformationView alloc] initWithFrame:CGRectMake(self.view.bounds.origin.x, CGRectGetMaxY(self.lineChart.frame), self.view.bounds.size.width, 100) layout:JBChartInformationViewLayoutVertical];
    [self.infoView setValueAndUnitTextColor:[UIColor colorWithWhite:1.0 alpha:0.75]];
    [self.infoView setTitleTextColor:[UIColor blackColor]];
    [self.infoView setValueAndUnitTextColor:PNTwitterColor];
    [self.infoView setTextShadowColor:nil];
    [self.infoView setSeparatorColor:[UIColor blackColor]];
    [self.view addSubview:self.infoView];
}

static bool bannerHasBeenLoaded = NO;

- (void)setupADBanner
{
    if (!self.iAd) {
        self.iAd = [[ADBannerView alloc] initWithAdType:ADAdTypeBanner];
        self.iAd.hidden = YES;
        CGRect iAdFrame = self.iAd.frame;
        iAdFrame.origin.y = self.view.frame.size.height-50;
        self.iAd.frame = iAdFrame;
        self.iAd.delegate = self;
        [self.view addSubview:self.iAd];
    }
}

#pragma mark - ADBanner delegate
- (void)bannerView:(ADBannerView *)banner didFailToReceiveAdWithError:(NSError *)error
{
    // When error happens, if the ad has been there, just keep it
    // otherwise, hide it.
    if (!bannerHasBeenLoaded) {
        self.iAd.hidden = YES;
    }
}

- (void)bannerViewDidLoadAd:(ADBannerView *)banner
{
    NSLog(@"Success233!");
    bannerHasBeenLoaded = YES;
    self.iAd.hidden = NO;
}

- (BOOL)bannerViewActionShouldBegin:(ADBannerView *)banner willLeaveApplication:(BOOL)willLeave
{
    return YES;
}
#pragma end

- (NSString *)getHeaderTitleFromRecord:(NSString *)record
{
    NSDateFormatter* df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSDate *date = [df dateFromString:record];
    [df setDateFormat:@"yyyy-MM-dd HH:mm"];
    return [df stringFromDate:date];
}

- (NSString *)getRecordNameFromRecordDate:(NSString *)record
{
    NSDateFormatter* df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSDate *date = [df dateFromString:record];
    [df setDateFormat:@"yyyy-MM-dd"];
    return [df stringFromDate:date];
}

- (void)showRecordFromDate:(NSString *)recordDate
{
    self.record = recordDate;
    NSString *docsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    self.recordPath = [docsPath stringByAppendingPathComponent:[[self getRecordNameFromRecordDate:recordDate] stringByAppendingString:@".csv"]];
}

#pragma mark - JBLineChartViewDelegate

- (CGFloat)lineChartView:(JBLineChartView *)lineChartView heightForIndex:(NSInteger)index
{
    NSArray *row = [self.recordData objectAtIndex:index];
    // Since the API returns NSInteger, and my data is double type, I multiply a big number to make it like some integer
    // and keep the relativity of line trend
    return [[row lastObject] floatValue] * 100;
}

- (void)lineChartView:(JBLineChartView *)lineChartView didSelectChartAtIndex:(NSInteger)index
{
    NSArray *row = [self.recordData objectAtIndex:index];
    
    NSNumber *speedValue = [NSNumber numberWithDouble:[[row lastObject] doubleValue] * SECONDS_OF_HOUR/RS_UNIT];
    NSString *valueText = [[NSString alloc] init];
    if ([speedValue doubleValue] > 10.0) {
        valueText = [NSString stringWithFormat:@"%.1f", [speedValue doubleValue]];
    }
    else {
        valueText = [NSString stringWithFormat:@"%.2f", [speedValue doubleValue]];
    }
    [self.infoView setValueText:valueText unitText:[@" " stringByAppendingString:RS_SPEED_UNIT_STRING]];
    
    CLLocationDistance distanceTitle = [[row objectAtIndex:1] doubleValue]/RS_UNIT;
    NSString *titleText = [[NSString alloc] init];
    if (distanceTitle > 10.0) {
        titleText = [NSString stringWithFormat:@"%.1f", distanceTitle];
    }
    else {
        titleText = [NSString stringWithFormat:@"%.2f", distanceTitle];
    }
    [self.infoView setTitleText:titleText unitText:[@" " stringByAppendingString:RS_DISTANCE_UNIT_STRING]];
    
    [self.infoView setHidden:NO animated:YES];
}

- (void)lineChartView:(JBLineChartView *)lineChartView didUnselectChartAtIndex:(NSInteger)index
{
    [self.infoView setHidden:YES animated:YES];
}

#pragma mark - JBLineChartViewDataSource

- (NSInteger)numberOfPointsInLineChartView:(JBLineChartView *)lineChartView
{
    return [self.recordData count]; // number of points in chart
}

- (UIColor *)lineColorForLineChartView:(JBLineChartView *)lineChartView
{
    return PNTwitterColor;
}

- (UIColor *)selectionColorForLineChartView:(JBLineChartView *)lineChartView
{
    return PNTwitterColor;
}

@end
