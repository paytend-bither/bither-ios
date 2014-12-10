//
//  RawPrivateKeyViewController.m
//  bither-ios
//
//  Copyright 2014 http://Bither.net
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

#import "RawPrivateKeyViewController.h"
#import "UIViewController+PiShowBanner.h"
#import "NSData+Hash.h"
#import "NSString+Base58.h"
#import "RawDataView.h"
#import "DialogProgress.h"
#import "StringUtil.h"
#import "BTKey.h"
#import <openssl/ecdsa.h>
#import <openssl/obj_mac.h>

#define PARAMETERS_N @"fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141"
#define PARAMETERS_MIN_N @"0"

@interface RawPrivateKeyViewController ()
@property (weak, nonatomic) IBOutlet UIView *vTopbar;

@property (weak, nonatomic) IBOutlet UIView *vInput;
@property (weak, nonatomic) IBOutlet RawDataView *vData;
@property (weak, nonatomic) IBOutlet UIView *vButtons;

@property (weak, nonatomic) IBOutlet UIView *vShow;
@property (weak, nonatomic) IBOutlet UILabel *lblPrivateKey;
@property (weak, nonatomic) IBOutlet UILabel *lblAddress;

@end

@implementation RawPrivateKeyViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.vData.restrictedSize = CGSizeMake(self.vData.frame.size.width, self.vInput.frame.size.height * 0.52f);
    self.vData.dataSize = CGSizeMake(16, 16);
    self.vButtons.frame = CGRectMake(self.vButtons.frame.origin.x, CGRectGetMaxY(self.vData.frame), self.vButtons.frame.size.width, self.vInput.frame.size.height - CGRectGetMaxY(self.vData.frame));
}

-(void)handleData{
    DialogProgress *dp = [[DialogProgress alloc]initWithMessage:NSLocalizedString(@"Please wait…", nil)];
    [dp showInWindow:self.view.window];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSMutableData* data = self.vData.data;
        if(!data){
            dispatch_async(dispatch_get_main_queue(), ^{
                [dp dismiss];
            });
            return;
        }
        if(![self checkData:data]){
            dispatch_async(dispatch_get_main_queue(), ^{
                [dp dismissWithCompletion:^{
                   [self showBannerWithMessage:NSLocalizedString(@"raw_private_key_not_safe", nil) belowView:self.vTopbar withCompletion:^{
                       self.vData.dataSize = CGSizeMake(16, 16);
                   }];
                }];
            });
            return;
        }
        data = [self modDataByN:data];
        BTKey* key = [[BTKey alloc]initWithSecret:data compressed:YES];
        NSString *privateKey = key.privateKey;
        NSString *address = key.address;
        dispatch_async(dispatch_get_main_queue(), ^{
            [dp dismiss];
            self.lblPrivateKey.text = [StringUtil formatAddress:privateKey groupSize:4 lineSize:16];
            self.lblAddress.text = [StringUtil formatAddress:address groupSize:4 lineSize:12];
            self.vShow.hidden = NO;
            self.vInput.hidden = YES;
        });
    });
}

-(void)addData:(BOOL)d{
    if(self.vData.filledDataLength < self.vData.dataLength){
        [self.vData addData:d];
        if(self.vData.filledDataLength >= self.vData.dataLength){
            [self performSelector:@selector(handleData) withObject:nil afterDelay:0.5];
        }
    }
}

- (IBAction)addPressed:(id)sender {
}

-(NSMutableData*)modDataByN:(NSMutableData*)data{
    if([data compare:[PARAMETERS_N hexToData]] > 0){
        BN_CTX *ctx = BN_CTX_new();
        BN_CTX_start(ctx);
        BIGNUM *n = BN_bin2bn([PARAMETERS_N hexToData].bytes, 32, NULL);
        BIGNUM *p = BN_bin2bn(data.bytes, 32, NULL);
        if(BN_mod(p, p, n, ctx) == 1){
            NSLog(@"mod success");
        }else{
            NSLog(@"mod failed");
        }
        data = [[NSMutableData alloc]initWithLength:data.length];
        int32_t num_bytes = BN_num_bytes(p);
        int32_t copied_bytes = BN_bn2bin(p, &data.mutableBytes[data.length - num_bytes]);
        if(num_bytes != copied_bytes){
            NSLog(@"length not match %d, %d", num_bytes, copied_bytes);
        }
        BN_free(n);
        BN_clear_free(p);
        BN_CTX_end(ctx);
        BN_CTX_free(ctx);
    }
    return data;
}

- (IBAction)zeroPressed:(id)sender {
    [self addData:NO];
}

- (IBAction)onePressed:(id)sender {
    [self addData:YES];
}

- (IBAction)backPressed:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

-(BOOL)checkData:(NSData*)data{
    if([data compare:[PARAMETERS_N hexToData]] == 0 || [data compare:[PARAMETERS_MIN_N hexToData]] == 0){
        return NO;
    }
    return YES;
}

@end
