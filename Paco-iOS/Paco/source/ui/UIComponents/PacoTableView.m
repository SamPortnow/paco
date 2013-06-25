/* Copyright 2013 Google Inc. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "PacoTableView.h"

#import <objc/runtime.h>

#import "PacoColor.h"
#import "PacoFont.h"
#import "PacoLoadingTableCell.h"
#import "PacoTableCell.h"
#import "PacoTableViewDelegate.h"

@interface PacoTableMapping : NSObject
@property (retain) NSString *stringKey;
@property (retain) Class dataClass;
@property (retain) Class cellClass;
@end

@implementation PacoTableMapping

@synthesize stringKey;
@synthesize dataClass;
@synthesize cellClass;
@end

@interface PacoTableView () <UITableViewDataSource, UITableViewDelegate>
@property (retain) NSMutableDictionary *mappings;  // <NSString,PacoTableMapping>
@property (retain) NSMutableDictionary *stringKeyToDataClass;  // <NSString,Class>

- (NSString *)keyForDataClass:(Class)dataClass stringKey:(NSString *)stringKey;
- (PacoTableMapping *)mappingForDataClass:(Class)dataClass stringKey:(NSString *)stringKey;
- (void)setMappingForDataClass:(Class)dataClass toCellClass:(Class)cellClass withStringKey:(NSString *)stringKey;
@end

@implementation PacoTableView

@synthesize data = data_;
@synthesize delegate = delegate_;
@synthesize mappings = mappings_;
@synthesize tableView = tableView_;
@synthesize stringKeyToDataClass = stringKeyToDataClass_;
@synthesize header = header_;
@synthesize footer = footer_;

- (id)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    mappings_ = [[NSMutableDictionary alloc] init];
    stringKeyToDataClass_ = [[NSMutableDictionary alloc] init];

    tableView_ = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    tableView_.dataSource = self;
    tableView_.delegate = self;
    tableView_.backgroundColor = [PacoColor pacoLightBlue];
    tableView_.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self addSubview:tableView_];
    
    [self registerClass:[PacoLoadingTableCell class] forStringKey:@"LOADING" dataClass:[NSString class]];
  }
  return self;
}

- (UIView *)header {
  return header_;
}

- (void)setHeader:(UIView *)header {
  [header_ removeFromSuperview];
  header_ = header;
  if (header) {
    [self addSubview:header_];
  }
  [self setNeedsLayout];
}

- (UIView *)footer {
  return footer_;
}

- (void)setFooter:(UIView *)footer {
  [footer_ removeFromSuperview];
  footer_ = footer;
  if (footer) {
    [self addSubview:footer_];
  }
  [self setNeedsLayout];
  [self.tableView setNeedsDisplay];
}

- (NSArray *)data {
  @synchronized(self) {
    return data_;
  }
}

- (NSArray *)boxInputs:(NSArray *)inputs withKey:(NSString *)key {
  NSMutableArray *boxed = [NSMutableArray array];
  for (id input in inputs) {
    NSArray *boxedInput = [NSArray arrayWithObjects:key, input, nil];
    [boxed addObject:boxedInput];
  }
  return boxed;
}

- (BOOL)inputsNeedBoxing:(NSArray *)inputs {
  for (id obj in inputs) {
    BOOL boxed = [self isBoxedDataType:obj];
    if (!boxed) {
      return YES;
    }
  }
  return NO;
}

- (BOOL)isBoxedDataType:(id)rowData {
  
  if (![rowData isKindOfClass:[NSArray class]]) {
   /*
    assert(!"Your data is structured wrong...\n"
            "  Your data object should be a top level array of {key,object} "
               "where key is the string key passed when you registered the classes.\n"
            "  Eg [NSArray arrayWithObjects:\n"
            "          [NSArray arrayWithObjects:@\"my_data_field_01\", my_data1, nil],\n"
            "          [NSArray arrayWithObjects:@\"my_data_field_02\", my_data2, nil],\n"
            "          [NSArray arrayWithObjects:@\"my_data_field_03\", my_data3, nil],\n"
            "          [NSArray arrayWithObjects:@\"my_data_field_04\", my_data4, nil],\n"
            "          ,nil]\n");
            */
    return NO;
  }
  
  NSArray *array = rowData;
  if ([array count] != 2) {
    return NO;
  }
  id key = [array objectAtIndex:0];
  id data = [array objectAtIndex:1];
  if (![key isKindOfClass:[NSString class]]) {
    return NO;
  }
  Class dataClass = [stringKeyToDataClass_ objectForKey:key];
  if (!dataClass) {
    return NO;
  }
  if (![data isKindOfClass:dataClass]) {
    return NO;
  }
  return YES;
}

- (void)setLoadingSpinnerEnabledWithLoadingText:(NSString *)loadingText {
  NSArray *loadingTableData =
      [NSArray arrayWithObjects:
          [NSArray arrayWithObjects:@"LOADING", loadingText, nil],
          nil];
  [self setData:loadingTableData];
}

- (void)setData:(NSArray *)data {
  @synchronized(self) {
  
  
  
    // Either no arrays in the objects, or all arrays - no mixing.
    BOOL hasArrays = NO;
    BOOL allArrays = YES;
    for (id dataObj in data) {
      if ([dataObj isKindOfClass:[NSArray class]] && ![self isBoxedDataType:dataObj]) {
        hasArrays = YES;
      } else {
        allArrays = NO;
      }
    }
    assert(!hasArrays || allArrays);

    // Keep the structure consistent whether 1 section or N sections.
    if (!allArrays) {
      data_ = [[NSArray alloc] initWithObjects:data, nil];
    } else {
      data_ = data;
    }
    [tableView_ reloadData];
    [self setNeedsLayout];
  }
}

- (void)registerClass:(Class)cellClass forStringKey:(NSString *)stringKey dataClass:(Class)dataClass {
  NSString *reuseId = [self keyForDataClass:dataClass stringKey:stringKey];
  [tableView_ registerClass:cellClass forCellReuseIdentifier:reuseId];
  if (stringKey) {
    [stringKeyToDataClass_ setObject:dataClass forKey:stringKey];
  }
  [self setMappingForDataClass:dataClass toCellClass:cellClass withStringKey:stringKey];
}

- (void)layoutSubviews {
  self.backgroundColor = [PacoColor pacoLightBlue];
  CGRect headerFrame = self.header ? self.header.frame : CGRectZero;
  CGRect footerFrame = self.footer ? self.footer.frame : CGRectZero;
  CGFloat yStart = 0;
  if (self.header) {
    self.header.frame = CGRectMake(0, yStart, headerFrame.size.width, headerFrame.size.height);
    yStart += headerFrame.size.height;
  }
  
  self.tableView.frame = CGRectMake(0, yStart, self.frame.size.width, self.frame.size.height - headerFrame.size.height - footerFrame.size.height);
  yStart += self.tableView.frame.size.height;
  if (self.footer) {
    self.footer.frame = CGRectMake(0, yStart, self.frame.size.width, self.frame.size.height - yStart);
  }
}

#pragma mark - Private

- (NSString *)keyForDataClass:(Class)dataClass stringKey:(NSString *)stringKey {
  NSString *dataClassName = NSStringFromClass(dataClass);
  if ([dataClassName isEqualToString:@"__NSCFNumber"]) {
    dataClassName = @"NSNumber";
  }
  if ([dataClassName isEqualToString:@"__NSCFString"]) {
    dataClassName = @"NSString";
  }
  if ([dataClassName isEqualToString:@"__NSCFConstantString"]) {
    dataClassName = @"NSString";
  }
  if ([dataClassName isEqualToString:@"__NSCFArray"]) {
    dataClassName = @"NSArray";
  }
  if ([dataClassName isEqualToString:@"__NSArrayI"]) {
    dataClassName = @"NSArray";
  }
  if ([dataClassName isEqualToString:@"__NSCFBoolean"]) {
    dataClassName = @"NSNumber";
  }
   
  if ([stringKey length]) {
    return [NSString stringWithFormat:@"%@:%@", stringKey, dataClassName];
  }
  return dataClassName;
}

- (PacoTableMapping *)mappingForDataClass:(Class)dataClass stringKey:(NSString *)stringKey {
  NSString *key = [self keyForDataClass:dataClass stringKey:stringKey];
  PacoTableMapping *mapping =  [mappings_ objectForKey:key];
  if (mapping == nil) {
    NSLog(@"error");
  }
  assert(mapping);
  return mapping;
}

- (void)setMappingForDataClass:(Class)dataClass toCellClass:(Class)cellClass withStringKey:(NSString *)stringKey {
  NSString *key = [self keyForDataClass:dataClass stringKey:stringKey];
  assert(key);
  PacoTableMapping *mapping = [[PacoTableMapping alloc] init];
  mapping.dataClass = dataClass;
  mapping.cellClass = cellClass;
  mapping.stringKey = stringKey;
  [mappings_ setObject:mapping forKey:key];
}


#pragma mark - UITableViewDataSource required

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  assert(section < self.data.count);
  NSArray *sectionArray = [data_ objectAtIndex:section];
  return sectionArray.count;
}

- (id)rowDataForIndexPath:(NSIndexPath *)indexPath {
  NSArray *sectionData = [data_ objectAtIndex:indexPath.section];
  id rowData = [sectionData objectAtIndex:indexPath.row];
  return rowData;
}

- (Class)classForRowData:(id)rowData reuseIdOut:(NSString **)reuseIdOut {
  BOOL isKeyed = [self isBoxedDataType:rowData];
  NSString *stringKey = nil;
  id dataObj = nil;
  if (isKeyed) {
    NSArray *keyPair = rowData;
    stringKey = [keyPair objectAtIndex:0];
    dataObj = [keyPair objectAtIndex:1];
  } else {
    dataObj = rowData;
  }
  Class dataObjClass = [dataObj class];
  PacoTableMapping *mapping = [self mappingForDataClass:dataObjClass stringKey:stringKey];
  if (reuseIdOut) {
    *reuseIdOut = [self keyForDataClass:[dataObj class] stringKey:stringKey];
  }
  assert(mapping);
  return mapping ? [mapping.cellClass class] : nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  id rowData = [self rowDataForIndexPath:indexPath];
  NSString *reuseId = nil;
  Class viewClass = [self classForRowData:rowData reuseIdOut:&reuseId];
  assert([reuseId length] && viewClass);
  assert([viewClass isSubclassOfClass:[UITableViewCell class]]);
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseId forIndexPath:indexPath];
  if (!cell) {
    cell = [[viewClass alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseId];
  }
  assert(cell);
  if ([[cell class] isSubclassOfClass:[PacoTableCell class]]) {
    PacoTableCell *pacoCell = (PacoTableCell *)cell;
    pacoCell.tableDelegate = self.delegate;
    pacoCell.rowData = rowData;
    pacoCell.reuseId = reuseId;
    pacoCell.backgroundColor = [PacoColor pacoLightBlue];
    pacoCell.textLabel.font = [PacoFont pacoTableCellFont];
    pacoCell.detailTextLabel.font = [PacoFont pacoTableCellDetailFont];
  }
  [delegate_ initializeCell:cell withData:rowData forReuseId:reuseId];
  return cell;
}

#pragma mark - UITableViewDataSource optional

// Default is 1 if not implemented
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return self.data.count;
}

// fixed font style. use custom view (UILabel) if you want something different
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
  // TODO(gregvance): support section headers
  return nil;
}

//- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section;

// Editing

// Individual rows can opt out of having the -editing property set for them. If not implemented, all rows are assumed to be editable.
//- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath;

// Moving/reordering

// Allows the reorder accessory view to optionally be shown for a particular row. By default, the reorder control will be shown only if the datasource implements -tableView:moveRowAtIndexPath:toIndexPath:
//- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath;

// Index

//- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView;                                                    // return list of section titles to display in section index view (e.g. "ABCD...Z#")
//- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index;  // tell table which section corresponds to section title/index (e.g. "B",1))

// Data manipulation - insert and delete support

// After a row has the minus or plus button invoked (based on the UITableViewCellEditingStyle for the cell), the dataSource must commit the change
//- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath;

// Data manipulation - reorder / moving support

//- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath;

#pragma mark - UITableViewDelegate

// Display customization

//- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath;
//- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section NS_AVAILABLE_IOS(6_0);
//- (void)tableView:(UITableView *)tableView willDisplayFooterView:(UIView *)view forSection:(NSInteger)section NS_AVAILABLE_IOS(6_0);
//- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath*)indexPath NS_AVAILABLE_IOS(6_0);
//- (void)tableView:(UITableView *)tableView didEndDisplayingHeaderView:(UIView *)view forSection:(NSInteger)section NS_AVAILABLE_IOS(6_0);
//- (void)tableView:(UITableView *)tableView didEndDisplayingFooterView:(UIView *)view forSection:(NSInteger)section NS_AVAILABLE_IOS(6_0);

// Variable height support

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  id rowData = [self rowDataForIndexPath:indexPath];
  NSString *reuseId = nil;
  Class viewClass = [self classForRowData:rowData reuseIdOut:&reuseId];
  assert([reuseId length] && viewClass);
  assert([viewClass isSubclassOfClass:[UITableViewCell class]]);
  if ([[viewClass class] respondsToSelector:@selector(heightForData:)]) {
      id value = [viewClass performSelector:@selector(heightForData:)
                                 withObject:rowData];
      assert([value isKindOfClass:[NSNumber class]]);
      return [value intValue];
  }
  return 45;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  id rowData = [self rowDataForIndexPath:indexPath];
  NSString *reuseId = nil;
  Class viewClass = [self classForRowData:rowData reuseIdOut:&reuseId];
  ((void)viewClass);
  UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
  [delegate_ cellSelected:cell rowData:rowData reuseId:reuseId];
}

//- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section;
//- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section;

// Section header & footer information. Views are preferred over title should you decide to provide both

//- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section;   // custom view for header. will be adjusted to default or specified header height
//- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section;   // custom view for footer. will be adjusted to default or specified footer height

// Accessories (disclosures). 

//- (UITableViewCellAccessoryType)tableView:(UITableView *)tableView accessoryTypeForRowWithIndexPath:(NSIndexPath *)indexPath NS_DEPRECATED_IOS(2_0, 3_0);
//- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath;

// Selection

// -tableView:shouldHighlightRowAtIndexPath: is called when a touch comes down on a row. 
// Returning NO to that message halts the selection process and does not cause the currently selected row to lose its selected look while the touch is down.
//- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath NS_AVAILABLE_IOS(6_0);
//- (void)tableView:(UITableView *)tableView didHighlightRowAtIndexPath:(NSIndexPath *)indexPath NS_AVAILABLE_IOS(6_0);
//- (void)tableView:(UITableView *)tableView didUnhighlightRowAtIndexPath:(NSIndexPath *)indexPath NS_AVAILABLE_IOS(6_0);

// Called before the user changes the selection. Return a new indexPath, or nil, to change the proposed selection.
//- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath;
//- (NSIndexPath *)tableView:(UITableView *)tableView willDeselectRowAtIndexPath:(NSIndexPath *)indexPath NS_AVAILABLE_IOS(3_0);
// Called after the user changes the selection.
//- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;
//- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath NS_AVAILABLE_IOS(3_0);

// Editing

// Allows customization of the editingStyle for a particular cell located at 'indexPath'. If not implemented, all editable cells will have UITableViewCellEditingStyleDelete set for them when the table has editing property set to YES.
//- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath;
//- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath NS_AVAILABLE_IOS(3_0);

// Controls whether the background is indented while editing.  If not implemented, the default is YES.  This is unrelated to the indentation level below.  This method only applies to grouped style table views.
//- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath;

// The willBegin/didEnd methods are called whenever the 'editing' property is automatically changed by the table (allowing insert/delete/move). This is done by a swipe activating a single row
//- (void)tableView:(UITableView*)tableView willBeginEditingRowAtIndexPath:(NSIndexPath *)indexPath;
//- (void)tableView:(UITableView*)tableView didEndEditingRowAtIndexPath:(NSIndexPath *)indexPath;

// Moving/reordering

// Allows customization of the target row for a particular row as it is being moved/reordered
//- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath;

// Indentation

//- (NSInteger)tableView:(UITableView *)tableView indentationLevelForRowAtIndexPath:(NSIndexPath *)indexPath; // return 'depth' of row for hierarchies

// Copy/Paste.  All three methods must be implemented by the delegate.

//- (BOOL)tableView:(UITableView *)tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath NS_AVAILABLE_IOS(5_0);
//- (BOOL)tableView:(UITableView *)tableView canPerformAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender NS_AVAILABLE_IOS(5_0);
//- (void)tableView:(UITableView *)tableView performAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender NS_AVAILABLE_IOS(5_0);


@end