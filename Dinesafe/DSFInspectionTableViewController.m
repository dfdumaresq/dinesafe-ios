//
//  DinesafeInspectionDetailTableViewController.m
//  Dinesafe
//
//  Created by Matt Ruten on 2012-11-25.
//  Copyright (c) 2012 Matt Ruten. All rights reserved.
//

#import "DSFInspectionTableViewController.h"
#import "AddressBook/AddressBook.h"
#import "NSString+URLEncoding.h"
#import "Flurry.h"

@interface DSFInspectionTableViewController ()
@property (nonatomic, strong) NSMutableArray *tableCellHeights;
@property (nonatomic, strong) DSFEstablishmentExtendedInfoCell *extendedInfoCell;
@end

@implementation DSFInspectionTableViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.tableCellHeights = [[NSMutableArray alloc] init];

    [self fetchEstablishment];
    [self calculateTableCellHeights];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Action button tap & actions

- (IBAction)actionTap:(id) sender {
    // Show menu, with
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                             delegate:self
                                                    cancelButtonTitle:@"Cancel"
                                               destructiveButtonTitle:nil
                                                    otherButtonTitles:@"Open in Maps", //@"Post to Twitter", @"Post to Facebook",
                                  nil];
    [actionSheet showFromBarButtonItem:self.actionButton animated:YES];
    [Flurry logEvent:@"Establishment Action Button Tapped"];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    // ... TODO: post to FB and twitter ...
    switch (buttonIndex) {
        case 0:
            [Flurry logEvent:@"Establishment Action: Open in Maps"];
            [self openInMaps];
            break;
//        case 1:
//            [self postToTwitter];
//            break;
//        case 2:
//            [self postToFacebook];
//            break;
        default:
            break;
    }
}

- (void)openInMaps {
    Class mapItemClass = [MKMapItem class];
    if (mapItemClass && [mapItemClass respondsToSelector:@selector(openMapsWithItems:launchOptions:)]) {
        // iOS 6+
        NSDictionary *addressDict = @{
            (NSString *)kABPersonAddressStreetKey: self.establishment.address,
            (NSString *)kABPersonAddressCityKey: @"Toronto",
            (NSString *)kABPersonAddressStateKey: @"Ontario"
        };
        MKPlacemark *placemark = [[MKPlacemark alloc] initWithCoordinate:self.establishment.location
                                                       addressDictionary:addressDict];
        MKMapItem *mapItem = [[MKMapItem alloc] initWithPlacemark:placemark];
        [mapItem setName:self.establishment.latestName];
        [mapItem openInMapsWithLaunchOptions:nil];
    } else {
        // iOS 5
        UIApplication *app = [UIApplication sharedApplication];
        NSString *mapQuery = [[NSString stringWithFormat:@"%@, Toronto, ON", self.establishment.address] urlEncode];
        NSString *mapURL = [@"http://maps.google.com/?q=" stringByAppendingString:mapQuery];
        [app openURL:[NSURL URLWithString:mapURL]];
    }
}

//- (void)postToFacebook {
//    
//}
//
//- (void)postToTwitter {
//    
//}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return self.establishment.inspections.count + 2; // +2 for the establishment info cells
}

// Calculates and stores table heights, so we don't have to do the logic/calulations
//      constantly. i.e. a caching mechanism to avoid laggy scrolling
- (void)calculateTableCellHeights {
    NSLog(@"calculateTableCellHeights called");
    // Establishment Info
    self.tableCellHeights[0] = [NSNumber numberWithInt:110];
    
    // Map/Inspections Summary
    self.tableCellHeights[1] = [NSNumber numberWithInt:184];

    // Offset to take into account the two cells above
    int inspectionsOffset = 2;
    int numEstablishments = self.establishment.inspections.count;
    for (int i=inspectionsOffset; i < (numEstablishments + inspectionsOffset); i++) {
        // Reversing inspection order for this
        //     numEstablishments - 1   takes us to the end of the list (counting from 0)
        //     i + inspectionsOffset   subtracts the current inspection's index
        int inspectionIndex = numEstablishments - 1 - i + inspectionsOffset;
        DSFInspection *inspection = self.establishment.inspections[inspectionIndex];
        int cellHeight;
        if (inspection.infractions.count > 0) {
            // 120 is base height
            cellHeight = 120 + [inspection heightForInfractionsWithSize:CGSizeMake(208, 1000) andFont:[UIFont fontWithName:@"HelveticaNeue" size:12.0]];
        } else {
            cellHeight = 40;
        }
        self.tableCellHeights[i] = [NSNumber numberWithInt:cellHeight];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [self.tableCellHeights[indexPath.row] floatValue];
}


- (UITableViewCell *)establishmentInfoCell {
    DSFEstablishmentCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"EstablishmentInfo"];
    cell.establishment = self.establishment;
    [cell updateCellContent];
    return cell;
}

- (UITableViewCell *)establishmentExtendedInfoCell {
    if (self.extendedInfoCell == nil) {
        // Only create cell once, to avoid map resetting each time.
        self.extendedInfoCell = [self.tableView dequeueReusableCellWithIdentifier:@"EstablishmentExtendedInfo"];
        self.extendedInfoCell.establishment = self.establishment;
        [self.extendedInfoCell updateCellContent];
    }
    return self.extendedInfoCell;
}

- (UITableViewCell *)inspectionCellForIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"InspectionCell";
    DSFInspectionCell *cell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    // TODO: Move inspectionIndex and cell order/etc to a consolidated place, i.e. figure out cell heights and orders once, and then return that instead of doing the calculations on every cell load, Also we're calculating inspectionIndex in 2 different places and that's confusing to update. Also, I'm very tired right now and can't articulate myself very well.
    int inspectionIndex = self.establishment.inspections.count - 1 - indexPath.row + 2;  // reverse order
    cell.inspection = self.establishment.inspections[inspectionIndex];
    [cell setNeedsDisplay];
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == 0) {
        return [self establishmentInfoCell];
    } else if (indexPath.row == 1) {
        return [self establishmentExtendedInfoCell];
    } else {
        return [self inspectionCellForIndexPath:indexPath];
    }
}

#pragma mark = fetching data

- (void)fetchEstablishment {
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:nil];
    
    if (self.currentLocation != nil) {
        parameters[@"near"] = [NSString stringWithFormat:@"%f,%f",
                               self.currentLocation.coordinate.latitude,
                               self.currentLocation.coordinate.longitude];
    }
    NSString *establishmentPath = [NSString stringWithFormat:@"establishments/%d.json", self.establishment.establishmentId];
    [[DSFApiClient sharedInstance] getPath:establishmentPath parameters:parameters success:
     ^(AFHTTPRequestOperation *operation, id response) {
         
         [self.establishment updateWithDictionary:response[@"data"]];
         [self calculateTableCellHeights];
         [self.tableView reloadData];
         
     } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
         
         [[[UIAlertView alloc] initWithTitle:@"Error Fetching Data"
                                     message:@"Please try again later."
                                    delegate:nil
                           cancelButtonTitle:@"Close"
                           otherButtonTitles: nil] show];
         
         NSLog(@"%@", error);
         
     }];
    
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Navigation logic may go here. Create and push another view controller.
    /*
     <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController animated:YES];
     */
}

@end
