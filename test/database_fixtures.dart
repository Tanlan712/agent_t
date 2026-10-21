/// valorant-api.com 公開資料的假資料（欄位名稱與實際回應相同）。
Map<String, dynamic> vandalJson() => {
      'uuid': 'vandal',
      'displayName': '暴徒',
      'category': 'EEquippableCategory::Rifle',
      'displayIcon': 'vandal.png',
      'shopData': {
        'cost': 2900,
        'category': 'Rifles',
        'categoryText': '突擊步槍',
      },
      'weaponStats': {
        'fireRate': 9.75,
        'magazineSize': 25,
        'runSpeedMultiplier': 0.76,
        'equipTimeSeconds': 1,
        'reloadTimeSeconds': 2.5,
        'firstBulletAccuracy': 0.25,
        'shotgunPelletCount': 1,
        'wallPenetration': 'EWallPenetrationDisplayType::Medium',
        'feature': null,
        'fireMode': null,
        'altFireType': 'EWeaponAltFireDisplayType::ADS',
        'adsStats': {
          'zoomMultiplier': 1.25,
          'fireRate': 8.78,
          'runSpeedMultiplier': 0.76,
          'burstCount': 1,
          'firstBulletAccuracy': 0.157,
        },
        'altShotgunStats': null,
        'airBurstStats': null,
        'damageRanges': [
          {
            'rangeStartMeters': 0,
            'rangeEndMeters': 50,
            'headDamage': 160,
            'bodyDamage': 40,
            'legDamage': 34,
          },
        ],
      },
      'skins': [],
    };

Map<String, dynamic> classicJson() => {
      'uuid': 'classic',
      'displayName': '制式手槍',
      'category': 'EEquippableCategory::Sidearm',
      'displayIcon': 'classic.png',
      'shopData': {'cost': 0, 'categoryText': '手槍隨身武器'},
      'weaponStats': {
        'fireRate': 6.75,
        'magazineSize': 12,
        'wallPenetration': 'EWallPenetrationDisplayType::Low',
        'fireMode': 'EWeaponFireModeDisplayType::SemiAutomatic',
        'damageRanges': [],
      },
      'skins': [],
    };

Map<String, dynamic> meleeJson() => {
      'uuid': 'melee',
      'displayName': '近戰武器',
      'category': 'EEquippableCategory::Melee',
      'displayIcon': 'knife.png',
      'shopData': null,
      'weaponStats': null,
      'skins': [],
    };

Map<String, dynamic> ascentJson() => {
      'uuid': 'ascent',
      'displayName': '義境空島',
      'displayIcon': 'mini.png',
      'splash': 'splash.png',
      'coordinates': '45°26\'BF\'N',
      'tacticalDescription': 'A/B 據點',
      'xMultiplier': 0.00007,
      'yMultiplier': -0.00007,
      'xScalarToAdd': 0.8,
      'yScalarToAdd': 0.5,
      'callouts': [
        {
          'regionName': '大門',
          'superRegionName': 'A',
          'location': {'x': 4000, 'y': -5000, 'z': 0},
        },
        {
          'regionName': '中路',
          'superRegionName': '中路',
          'location': {'x': 0, 'y': 0, 'z': 0},
        },
      ],
    };

Map<String, dynamic> skinJson({required String uuid, required String theme}) =>
    {
      'uuid': uuid,
      'displayName': '造型 $uuid',
      'themeUuid': theme,
      'displayIcon': '$uuid.png',
      'levels': [
        {'uuid': 'l1', 'displayName': '等級 1', 'streamedVideo': null},
        {'uuid': 'l2', 'displayName': '等級 2', 'streamedVideo': 'lv2.mp4'},
      ],
      'chromas': [
        {
          'uuid': 'c1',
          'displayName': '原色',
          'displayIcon': 'c1.png',
          'fullRender': null,
          'swatch': null,
        },
        {
          'uuid': 'c2',
          'displayName': '紅色',
          'displayIcon': 'c2.png',
          'fullRender': 'c2-full.png',
          'swatch': 'c2-swatch.png',
        },
      ],
    };

Map<String, dynamic> agentJson() => {
      'uuid': 'jett',
      'displayName': '捷風',
      'description': '來自南韓的決鬥者',
      'displayIcon': 'jett.png',
      'fullPortrait': 'jett-full.png',
      'background': 'bg.png',
      'role': {'displayName': '決鬥者'},
      'abilities': [
        {
          'slot': 'Ultimate',
          'displayName': '技能 X',
          'description': 'x',
          'displayIcon': 'x.png'
        },
        {
          'slot': 'Passive',
          'displayName': '被動',
          'description': 'p',
          'displayIcon': null
        },
        {
          'slot': 'Ability2',
          'displayName': '技能 E',
          'description': 'e',
          'displayIcon': 'e.png'
        },
        {
          'slot': 'Grenade',
          'displayName': '技能 C',
          'description': 'c',
          'displayIcon': 'c.png'
        },
        {
          'slot': 'Ability1',
          'displayName': '技能 Q',
          'description': 'q',
          'displayIcon': 'q.png'
        },
      ],
    };
