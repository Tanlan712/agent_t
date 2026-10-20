/// 依社群文件（valapidocs）格式精簡的 storefront 測試資料。
const vp = '85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741';

Map<String, dynamic> offer(String itemId, int cost) => {
      'OfferID': itemId,
      'IsDirectPurchase': true,
      'Cost': {vp: cost},
      'Rewards': [
        {'ItemTypeID': 'e7c63390-eda7-46e0-bb7a-a6abdacd2433', 'ItemID': itemId, 'Quantity': 1},
      ],
    };

Map<String, dynamic> storefrontJson({bool withNightMarket = true}) => {
      'FeaturedBundle': {
        'Bundle': {
          'ID': 'b-offer',
          'DataAssetID': 'bundle-rgx',
          'CurrencyID': vp,
          'TotalBaseCost': {vp: 8700},
          'TotalDiscountedCost': {vp: 7100},
          'DurationRemainingInSeconds': 500000,
        },
        'BundleRemainingDurationInSeconds': 500000,
      },
      'SkinsPanelLayout': {
        'SingleItemOffers': ['lvl-odin', 'lvl-noicon', 'lvl-a', 'lvl-unknown'],
        'SingleItemStoreOffers': [
          offer('lvl-odin', 1275),
          offer('lvl-noicon', 2475),
          offer('lvl-a', 875),
          offer('lvl-unknown', 1775),
        ],
        'SingleItemOffersRemainingDurationInSeconds': 3600,
      },
      if (withNightMarket)
        'BonusStore': {
          'BonusStoreOffers': [
            {
              'BonusOfferID': 'n1',
              'Offer': offer('lvl-odin', 1275),
              'DiscountPercent': 30,
              'DiscountCosts': {vp: 893},
              'IsSeen': false,
            },
            {
              'BonusOfferID': 'n2',
              'Offer': offer('lvl-noicon', 2475),
              'DiscountPercent': 20,
              'DiscountCosts': {vp: 1980},
              'IsSeen': false,
            },
          ],
          'BonusStoreRemainingDurationInSeconds': 86400,
        },
    };
