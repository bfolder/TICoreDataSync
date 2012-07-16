//
//  TINBNote.h
//  Notebook
//
//  Created by Tim Isted on 04/05/2011.
//  Copyright (c) 2011 Tim Isted. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "TICoreDataSync.h"

@class TINBTag;
@class TINBImageWrapper;

@interface TINBNote : TICDSSynchronizedManagedObject {
@private
}
@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSString * content;
@property (nonatomic, retain) NSSet* tags;
@property (nonatomic, retain) NSData *imageData;
@property (nonatomic, retain) UIImage *image;

@end
