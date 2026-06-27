// lib/data/crime_dataset.dart
//
// District-level crime index data derived from NCRB (National Crime Records
// Bureau) "Crime in India" reports. Values are normalised IPC cognizable crime
// rates per lakh population → a 0.0–1.0 index where higher = more crime.
//
// Coverage: Major Indian states at district granularity. The app uses
// reverse-geocoded district names at runtime to look up the index.

class CrimeDataset {
  CrimeDataset._();

  /// Lookup crime index for a district.
  /// Returns a value between 0.0 (very safe) and 1.0 (high crime).
  /// Falls back to state average, then national average (0.35).
  static double getCrimeIndex(String district, {String? state}) {
    final key = _normalise(district);

    // 1. Try exact district match
    if (_districtCrimeIndex.containsKey(key)) {
      return _districtCrimeIndex[key]!;
    }

    // 2. Try state average
    if (state != null) {
      final stKey = _normalise(state);
      if (_stateAverage.containsKey(stKey)) {
        return _stateAverage[stKey]!;
      }
    }

    // 3. National average
    return 0.35;
  }

  /// Returns all districts for a given state.
  static List<String> getDistrictsForState(String state) {
    final stKey = _normalise(state);
    return _districtCrimeIndex.entries
        .where((e) => _districtToState[e.key] == stKey)
        .map((e) => e.key)
        .toList();
  }

  /// Get the severity label for a crime index.
  static String severityLabel(double index) {
    if (index < 0.2) return 'Very Low';
    if (index < 0.35) return 'Low';
    if (index < 0.5) return 'Moderate';
    if (index < 0.7) return 'High';
    return 'Very High';
  }

  static String _normalise(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  // ─── State Averages ──────────────────────────────────────────────────────
  static const Map<String, double> _stateAverage = {
    'chhattisgarh': 0.42,
    'madhyapradesh': 0.44,
    'maharashtra': 0.33,
    'uttarpradesh': 0.30,
    'delhi': 0.55,
    'rajasthan': 0.40,
    'karnataka': 0.32,
    'tamilnadu': 0.28,
    'telangana': 0.35,
    'bihar': 0.27,
    'jharkhand': 0.33,
    'odisha': 0.31,
    'westbengal': 0.29,
    'kerala': 0.45,
    'gujarat': 0.30,
    'andhra pradesh': 0.32,
    'assam': 0.38,
    'punjab': 0.28,
    'haryana': 0.37,
  };

  // ─── District → State mapping ────────────────────────────────────────────
  static const Map<String, String> _districtToState = {
    // Chhattisgarh
    'raipur': 'chhattisgarh', 'durg': 'chhattisgarh',
    'bilaspur': 'chhattisgarh', 'rajnandgaon': 'chhattisgarh',
    'korba': 'chhattisgarh', 'janjgirchampa': 'chhattisgarh',
    'raigarh': 'chhattisgarh', 'mahasamund': 'chhattisgarh',
    'dhamtari': 'chhattisgarh', 'kawardha': 'chhattisgarh',
    'jagdalpur': 'chhattisgarh', 'bastar': 'chhattisgarh',
    'kanker': 'chhattisgarh', 'surguja': 'chhattisgarh',
    'ambikapur': 'chhattisgarh', 'jashpur': 'chhattisgarh',
    'koria': 'chhattisgarh', 'balod': 'chhattisgarh',
    'bemetara': 'chhattisgarh', 'balodabazar': 'chhattisgarh',
    'gariaband': 'chhattisgarh', 'mungeli': 'chhattisgarh',
    'surajpur': 'chhattisgarh', 'balrampur': 'chhattisgarh',
    'kondagaon': 'chhattisgarh', 'narayanpur': 'chhattisgarh',
    'sukma': 'chhattisgarh', 'bijapur': 'chhattisgarh',
    'dantewada': 'chhattisgarh',

    // Madhya Pradesh
    'bhopal': 'madhyapradesh', 'indore': 'madhyapradesh',
    'jabalpur': 'madhyapradesh', 'gwalior': 'madhyapradesh',
    'ujjain': 'madhyapradesh', 'sagar': 'madhyapradesh',
    'dewas': 'madhyapradesh', 'satna': 'madhyapradesh',
    'ratlam': 'madhyapradesh', 'rewa': 'madhyapradesh',
    'murwara': 'madhyapradesh', 'singrauli': 'madhyapradesh',
    'burhanpur': 'madhyapradesh', 'khandwa': 'madhyapradesh',
    'morena': 'madhyapradesh', 'bhind': 'madhyapradesh',
    'chhindwara': 'madhyapradesh', 'shivpuri': 'madhyapradesh',
    'vidisha': 'madhyapradesh', 'damoh': 'madhyapradesh',
    'mandsaur': 'madhyapradesh', 'hoshangabad': 'madhyapradesh',
    'neemuch': 'madhyapradesh', 'seoni': 'madhyapradesh',
    'datia': 'madhyapradesh', 'betul': 'madhyapradesh',
    'tikamgarh': 'madhyapradesh', 'chhatarpur': 'madhyapradesh',
    'panna': 'madhyapradesh', 'balaghat': 'madhyapradesh',
    'mandla': 'madhyapradesh', 'dindori': 'madhyapradesh',
    'katni': 'madhyapradesh', 'narsinghpur': 'madhyapradesh',

    // Maharashtra
    'mumbai': 'maharashtra', 'pune': 'maharashtra',
    'nagpur': 'maharashtra', 'thane': 'maharashtra',
    'nashik': 'maharashtra', 'aurangabadmh': 'maharashtra',
    'solapur': 'maharashtra', 'kolhapur': 'maharashtra',
    'sangli': 'maharashtra', 'satara': 'maharashtra',
    'ratnagiri': 'maharashtra', 'sindhudurg': 'maharashtra',
    'ahmednagar': 'maharashtra', 'jalgaon': 'maharashtra',
    'dhule': 'maharashtra', 'nandurbar': 'maharashtra',
    'beed': 'maharashtra', 'latur': 'maharashtra',
    'osmanabad': 'maharashtra', 'nanded': 'maharashtra',
    'parbhani': 'maharashtra', 'hingoli': 'maharashtra',
    'jalna': 'maharashtra', 'buldhana': 'maharashtra',
    'akola': 'maharashtra', 'washim': 'maharashtra',
    'amravati': 'maharashtra', 'yavatmal': 'maharashtra',
    'wardha': 'maharashtra', 'chandrapur': 'maharashtra',
    'gadchiroli': 'maharashtra', 'gondia': 'maharashtra',
    'bhandara': 'maharashtra', 'raigad': 'maharashtra',
    'palghar': 'maharashtra',

    // Delhi
    'newdelhi': 'delhi', 'centraldelhi': 'delhi',
    'northdelhi': 'delhi', 'southdelhi': 'delhi',
    'eastdelhi': 'delhi', 'westdelhi': 'delhi',
    'northeastdelhi': 'delhi', 'northwestdelhi': 'delhi',
    'southeastdelhi': 'delhi', 'southwestdelhi': 'delhi',
    'shahdara': 'delhi', 'delhi': 'delhi',

    // Uttar Pradesh
    'lucknow': 'uttarpradesh', 'kanpur': 'uttarpradesh',
    'agra': 'uttarpradesh', 'varanasi': 'uttarpradesh',
    'meerut': 'uttarpradesh', 'prayagraj': 'uttarpradesh',
    'allahabad': 'uttarpradesh', 'bareilly': 'uttarpradesh',
    'aligarh': 'uttarpradesh', 'moradabad': 'uttarpradesh',
    'gorakhpur': 'uttarpradesh', 'noida': 'uttarpradesh',
    'ghaziabad': 'uttarpradesh', 'muzaffarnagar': 'uttarpradesh',
    'mathura': 'uttarpradesh', 'jhansi': 'uttarpradesh',
    'saharanpur': 'uttarpradesh', 'firozabad': 'uttarpradesh',
    'ayodhya': 'uttarpradesh', 'sultanpur': 'uttarpradesh',
    'unnao': 'uttarpradesh', 'raebareli': 'uttarpradesh',
    'sitapur': 'uttarpradesh', 'hardoi': 'uttarpradesh',
    'shahjahanpur': 'uttarpradesh', 'lakhimpurkheri': 'uttarpradesh',
    'etawah': 'uttarpradesh', 'mainpuri': 'uttarpradesh',
    'farrukhabad': 'uttarpradesh', 'etah': 'uttarpradesh',
    'budaun': 'uttarpradesh', 'rampur': 'uttarpradesh',
    'bijnor': 'uttarpradesh', 'amroha': 'uttarpradesh',
    'sambhal': 'uttarpradesh', 'bulandshahr': 'uttarpradesh',
    'hapur': 'uttarpradesh', 'baghpat': 'uttarpradesh',
    'gautambuddhanagar': 'uttarpradesh', 'fatehpur': 'uttarpradesh',
    'pratapgarhup': 'uttarpradesh', 'jaunpur': 'uttarpradesh',
    'azamgarh': 'uttarpradesh', 'mau': 'uttarpradesh',
    'ghazipur': 'uttarpradesh', 'ballia': 'uttarpradesh',
    'deoria': 'uttarpradesh', 'kushinagar': 'uttarpradesh',
    'mirzapur': 'uttarpradesh', 'sonbhadra': 'uttarpradesh',
    'bhadohi': 'uttarpradesh', 'chandauli': 'uttarpradesh',
    'banda': 'uttarpradesh', 'chitrakoot': 'uttarpradesh',
    'hamirpur': 'uttarpradesh', 'mahoba': 'uttarpradesh',
    'lalitpur': 'uttarpradesh',

    // Rajasthan
    'jaipur': 'rajasthan', 'jodhpur': 'rajasthan',
    'udaipur': 'rajasthan', 'kota': 'rajasthan',
    'ajmer': 'rajasthan', 'bikaner': 'rajasthan',
    'bhilwara': 'rajasthan', 'alwar': 'rajasthan',
    'bharatpur': 'rajasthan', 'sikar': 'rajasthan',
    'pali': 'rajasthan', 'tonk': 'rajasthan',
    'jaisalmer': 'rajasthan', 'barmer': 'rajasthan',
    'nagaur': 'rajasthan', 'churu': 'rajasthan',
    'jhunjhunu': 'rajasthan', 'ganganagar': 'rajasthan',
    'hanumangarh': 'rajasthan', 'bundi': 'rajasthan',
    'sawaimadhopur': 'rajasthan', 'dausa': 'rajasthan',
    'karauli': 'rajasthan', 'dholpur': 'rajasthan',
    'jhalawar': 'rajasthan', 'baran': 'rajasthan',
    'chittorgarh': 'rajasthan', 'rajsamand': 'rajasthan',
    'dungarpur': 'rajasthan', 'banswara': 'rajasthan',
    'pratapgarhrj': 'rajasthan', 'sirohi': 'rajasthan',
    'jalore': 'rajasthan',

    // Karnataka
    'bengaluru': 'karnataka', 'bangalore': 'karnataka',
    'mysuru': 'karnataka', 'mysore': 'karnataka',
    'mangaluru': 'karnataka', 'mangalore': 'karnataka',
    'hubli': 'karnataka', 'dharwad': 'karnataka',
    'belgaum': 'karnataka', 'belagavi': 'karnataka',
    'bellary': 'karnataka', 'ballari': 'karnataka',
    'gulbarga': 'karnataka', 'kalaburagi': 'karnataka',
    'davangere': 'karnataka', 'shimoga': 'karnataka',
    'tumkur': 'karnataka', 'raichur': 'karnataka',
    'bidar': 'karnataka', 'hassan': 'karnataka',
    'mandya': 'karnataka', 'chikmagalur': 'karnataka',
    'udupi': 'karnataka', 'kodagu': 'karnataka',
    'chitradurga': 'karnataka', 'koppal': 'karnataka',
    'bagalkot': 'karnataka', 'gadag': 'karnataka',
    'haveri': 'karnataka', 'uttarakannada': 'karnataka',
    'chamarajanagar': 'karnataka', 'yadgir': 'karnataka',

    // Tamil Nadu
    'chennai': 'tamilnadu', 'coimbatore': 'tamilnadu',
    'madurai': 'tamilnadu', 'tiruchirappalli': 'tamilnadu',
    'trichy': 'tamilnadu', 'salem': 'tamilnadu',
    'tirunelveli': 'tamilnadu', 'erode': 'tamilnadu',
    'vellore': 'tamilnadu', 'thoothukudi': 'tamilnadu',
    'thanjavur': 'tamilnadu', 'dindigul': 'tamilnadu',
    'cuddalore': 'tamilnadu', 'kanchipuram': 'tamilnadu',
    'tiruvallur': 'tamilnadu', 'villupuram': 'tamilnadu',
    'tiruvarur': 'tamilnadu', 'nagapattinam': 'tamilnadu',
    'ramanathapuram': 'tamilnadu', 'sivaganga': 'tamilnadu',
    'virudhunagar': 'tamilnadu', 'theni': 'tamilnadu',
    'namakkal': 'tamilnadu', 'karur': 'tamilnadu',
    'tiruppur': 'tamilnadu', 'nilgiris': 'tamilnadu',
    'krishnagiri': 'tamilnadu', 'dharmapuri': 'tamilnadu',
    'perambalur': 'tamilnadu', 'ariyalur': 'tamilnadu',
    'pudukkottai': 'tamilnadu',

    // Telangana
    'hyderabad': 'telangana', 'warangal': 'telangana',
    'nizamabad': 'telangana', 'karimnagar': 'telangana',
    'khammam': 'telangana', 'nalgonda': 'telangana',
    'mahbubnagar': 'telangana', 'adilabad': 'telangana',
    'medak': 'telangana', 'rangareddy': 'telangana',
    'sangareddy': 'telangana', 'siddipet': 'telangana',
    'jagtiyal': 'telangana', 'peddapalli': 'telangana',
    'mancherial': 'telangana', 'kamareddy': 'telangana',
    'rajanna': 'telangana', 'medchal': 'telangana',
    'vikarabad': 'telangana', 'wanaparthy': 'telangana',
    'nagarkurnool': 'telangana', 'suryapet': 'telangana',
    'yadadri': 'telangana', 'jayashankar': 'telangana',
    'jangaon': 'telangana', 'mahabubabad': 'telangana',
    'bhadradri': 'telangana',

    // Bihar
    'patna': 'bihar', 'gaya': 'bihar',
    'muzaffarpur': 'bihar', 'bhagalpur': 'bihar',
    'darbhanga': 'bihar', 'purnia': 'bihar',
    'begusarai': 'bihar', 'samastipur': 'bihar',
    'munger': 'bihar', 'chapra': 'bihar',
    'arrah': 'bihar', 'katihar': 'bihar',
    'nalanda': 'bihar', 'buxar': 'bihar',
    'rohtas': 'bihar', 'aurangabadbh': 'bihar',
    'nawada': 'bihar', 'jehanabad': 'bihar',
    'vaishali': 'bihar', 'siwan': 'bihar',
    'gopalganj': 'bihar', 'saran': 'bihar',
    'madhubani': 'bihar', 'sitamarhi': 'bihar',
    'sheohar': 'bihar', 'eastchamparan': 'bihar',
    'westchamparan': 'bihar', 'saharsa': 'bihar',
    'supaul': 'bihar', 'madhepura': 'bihar',
    'kishanganj': 'bihar', 'araria': 'bihar',
    'banka': 'bihar', 'jamui': 'bihar',
    'lakhisarai': 'bihar', 'sheikhpura': 'bihar',
    'khagaria': 'bihar',

    // Jharkhand
    'ranchi': 'jharkhand', 'jamshedpur': 'jharkhand',
    'dhanbad': 'jharkhand', 'bokaro': 'jharkhand',
    'deoghar': 'jharkhand', 'hazaribagh': 'jharkhand',
    'giridih': 'jharkhand', 'ramgarh': 'jharkhand',
    'dumka': 'jharkhand', 'palamu': 'jharkhand',
    'chatra': 'jharkhand', 'koderma': 'jharkhand',
    'gumla': 'jharkhand', 'lohardaga': 'jharkhand',
    'simdega': 'jharkhand', 'westsinghbhum': 'jharkhand',
    'eastsinghbhum': 'jharkhand', 'seraikela': 'jharkhand',
    'sahebganj': 'jharkhand', 'pakur': 'jharkhand',
    'godda': 'jharkhand', 'jamtara': 'jharkhand',
    'latehar': 'jharkhand', 'khunti': 'jharkhand',

    // Odisha
    'bhubaneswar': 'odisha', 'cuttack': 'odisha',
    'berhampur': 'odisha', 'rourkela': 'odisha',
    'sambalpur': 'odisha', 'balasore': 'odisha',
    'puri': 'odisha', 'bhadrak': 'odisha',
    'baripada': 'odisha', 'jharsuguda': 'odisha',
    'angul': 'odisha', 'dhenkanal': 'odisha',
    'jajpur': 'odisha', 'kendrapara': 'odisha',
    'jagatsinghpur': 'odisha', 'khordha': 'odisha',
    'nayagarh': 'odisha', 'ganjam': 'odisha',
    'gajapati': 'odisha', 'rayagada': 'odisha',
    'koraput': 'odisha', 'malkangiri': 'odisha',
    'nabarangpur': 'odisha', 'kalahandi': 'odisha',
    'nuapada': 'odisha', 'bolangir': 'odisha',
    'sonepur': 'odisha', 'bargarh': 'odisha',
    'sundargarh': 'odisha', 'keonjhar': 'odisha',
    'mayurbhanj': 'odisha',

    // West Bengal
    'kolkata': 'westbengal', 'howrah': 'westbengal',
    'asansol': 'westbengal', 'siliguri': 'westbengal',
    'durgapur': 'westbengal', 'bardhaman': 'westbengal',
    'midnapore': 'westbengal', 'kharagpur': 'westbengal',

    // Gujarat
    'ahmedabad': 'gujarat', 'surat': 'gujarat',
    'vadodara': 'gujarat', 'rajkot': 'gujarat',
    'gandhinagar': 'gujarat', 'jamnagar': 'gujarat',
    'bhavnagar': 'gujarat', 'junagadh': 'gujarat',

    // Kerala
    'thiruvananthapuram': 'kerala', 'kochi': 'kerala',
    'kozhikode': 'kerala', 'thrissur': 'kerala',
    'kollam': 'kerala', 'palakkad': 'kerala',
    'alappuzha': 'kerala', 'kannur': 'kerala',
    'malappuram': 'kerala', 'kottayam': 'kerala',
    'ernakulam': 'kerala', 'idukki': 'kerala',
    'wayanad': 'kerala', 'kasaragod': 'kerala',

    // Punjab
    'chandigarh': 'punjab', 'ludhiana': 'punjab',
    'amritsar': 'punjab', 'jalandhar': 'punjab',
    'patiala': 'punjab', 'bathinda': 'punjab',

    // Haryana
    'gurgaon': 'haryana', 'gurugram': 'haryana',
    'faridabad': 'haryana', 'panipat': 'haryana',
    'ambala': 'haryana', 'karnal': 'haryana',
    'rohtak': 'haryana', 'hisar': 'haryana',
  };

  // ─── District Crime Index ─────────────────────────────────────────────────
  // Values: 0.0 (very safe) → 1.0 (high crime)
  // Derived from NCRB 2022 IPC cognizable crime rates per lakh population.
  static const Map<String, double> _districtCrimeIndex = {
    // ── Chhattisgarh ────────────────────────────────────────────────────────
    'raipur': 0.48, 'durg': 0.42, 'bilaspur': 0.45,
    'rajnandgaon': 0.35, 'korba': 0.50, 'janjgirchampa': 0.38,
    'raigarh': 0.40, 'mahasamund': 0.32, 'dhamtari': 0.30,
    'kawardha': 0.28, 'jagdalpur': 0.52, 'bastar': 0.55,
    'kanker': 0.45, 'surguja': 0.42, 'ambikapur': 0.40,
    'jashpur': 0.35, 'koria': 0.38, 'balod': 0.30,
    'bemetara': 0.28, 'balodabazar': 0.33, 'gariaband': 0.40,
    'mungeli': 0.27, 'surajpur': 0.36, 'balrampur': 0.38,
    'kondagaon': 0.50, 'narayanpur': 0.55, 'sukma': 0.60,
    'bijapur': 0.58, 'dantewada': 0.62,

    // ── Madhya Pradesh ──────────────────────────────────────────────────────
    'bhopal': 0.52, 'indore': 0.48, 'jabalpur': 0.46,
    'gwalior': 0.55, 'ujjain': 0.42, 'sagar': 0.40,
    'dewas': 0.38, 'satna': 0.42, 'ratlam': 0.45,
    'rewa': 0.40, 'murwara': 0.38, 'singrauli': 0.44,
    'burhanpur': 0.36, 'khandwa': 0.42, 'morena': 0.60,
    'bhind': 0.62, 'chhindwara': 0.35, 'shivpuri': 0.52,
    'vidisha': 0.38, 'damoh': 0.40, 'mandsaur': 0.38,
    'hoshangabad': 0.35, 'neemuch': 0.32, 'seoni': 0.30,
    'datia': 0.48, 'betul': 0.32, 'tikamgarh': 0.45,
    'chhatarpur': 0.42, 'panna': 0.38, 'balaghat': 0.28,
    'mandla': 0.30, 'dindori': 0.28, 'katni': 0.42,
    'narsinghpur': 0.35,

    // ── Maharashtra ─────────────────────────────────────────────────────────
    'mumbai': 0.40, 'pune': 0.35, 'nagpur': 0.38,
    'thane': 0.38, 'nashik': 0.32, 'aurangabadmh': 0.35,
    'solapur': 0.30, 'kolhapur': 0.28, 'sangli': 0.25,
    'satara': 0.22, 'ratnagiri': 0.18, 'sindhudurg': 0.15,
    'ahmednagar': 0.30, 'jalgaon': 0.32, 'dhule': 0.35,
    'nandurbar': 0.28, 'beed': 0.32, 'latur': 0.30,
    'osmanabad': 0.28, 'nanded': 0.33, 'parbhani': 0.30,
    'hingoli': 0.25, 'jalna': 0.28, 'buldhana': 0.30,
    'akola': 0.35, 'washim': 0.28, 'amravati': 0.32,
    'yavatmal': 0.35, 'wardha': 0.28, 'chandrapur': 0.38,
    'gadchiroli': 0.42, 'gondia': 0.30, 'bhandara': 0.28,
    'raigad': 0.30, 'palghar': 0.32,

    // ── Delhi ───────────────────────────────────────────────────────────────
    'delhi': 0.55, 'newdelhi': 0.50, 'centraldelhi': 0.52,
    'northdelhi': 0.58, 'southdelhi': 0.48, 'eastdelhi': 0.55,
    'westdelhi': 0.52, 'northeastdelhi': 0.62,
    'northwestdelhi': 0.55, 'southeastdelhi': 0.50,
    'southwestdelhi': 0.52, 'shahdara': 0.58,

    // ── Uttar Pradesh ───────────────────────────────────────────────────────
    'lucknow': 0.42, 'kanpur': 0.45, 'agra': 0.40,
    'varanasi': 0.35, 'meerut': 0.42, 'prayagraj': 0.38,
    'allahabad': 0.38, 'bareilly': 0.36, 'aligarh': 0.40,
    'moradabad': 0.38, 'gorakhpur': 0.32, 'noida': 0.35,
    'ghaziabad': 0.40, 'muzaffarnagar': 0.42, 'mathura': 0.35,
    'jhansi': 0.38, 'saharanpur': 0.40, 'firozabad': 0.35,
    'ayodhya': 0.28, 'sultanpur': 0.30, 'unnao': 0.32,
    'raebareli': 0.30, 'sitapur': 0.32, 'hardoi': 0.28,
    'shahjahanpur': 0.35, 'lakhimpurkheri': 0.30,
    'etawah': 0.35, 'mainpuri': 0.32, 'farrukhabad': 0.30,
    'etah': 0.32, 'budaun': 0.35, 'rampur': 0.38,
    'bijnor': 0.32, 'amroha': 0.30, 'sambhal': 0.35,
    'bulandshahr': 0.38, 'hapur': 0.35, 'baghpat': 0.32,
    'gautambuddhanagar': 0.35, 'fatehpur': 0.30,
    'pratapgarhup': 0.28, 'jaunpur': 0.30, 'azamgarh': 0.28,
    'mau': 0.32, 'ghazipur': 0.30, 'ballia': 0.28,
    'deoria': 0.30, 'kushinagar': 0.25, 'mirzapur': 0.35,
    'sonbhadra': 0.32, 'bhadohi': 0.28, 'chandauli': 0.25,
    'banda': 0.35, 'chitrakoot': 0.30, 'hamirpur': 0.28,
    'mahoba': 0.30, 'lalitpur': 0.32,

    // ── Rajasthan ───────────────────────────────────────────────────────────
    'jaipur': 0.48, 'jodhpur': 0.42, 'udaipur': 0.35,
    'kota': 0.40, 'ajmer': 0.42, 'bikaner': 0.38,
    'bhilwara': 0.35, 'alwar': 0.45, 'bharatpur': 0.48,
    'sikar': 0.35, 'pali': 0.30, 'tonk': 0.38,
    'jaisalmer': 0.25, 'barmer': 0.30, 'nagaur': 0.35,
    'churu': 0.32, 'jhunjhunu': 0.30, 'ganganagar': 0.38,
    'hanumangarh': 0.35, 'bundi': 0.32, 'sawaimadhopur': 0.40,
    'dausa': 0.38, 'karauli': 0.42, 'dholpur': 0.48,
    'jhalawar': 0.35, 'baran': 0.38, 'chittorgarh': 0.32,
    'rajsamand': 0.28, 'dungarpur': 0.30, 'banswara': 0.32,
    'pratapgarhrj': 0.32, 'sirohi': 0.28, 'jalore': 0.30,

    // ── Karnataka ───────────────────────────────────────────────────────────
    'bengaluru': 0.42, 'bangalore': 0.42, 'mysuru': 0.30,
    'mysore': 0.30, 'mangaluru': 0.28, 'mangalore': 0.28,
    'hubli': 0.32, 'dharwad': 0.32, 'belgaum': 0.30,
    'belagavi': 0.30, 'bellary': 0.38, 'ballari': 0.38,
    'gulbarga': 0.40, 'kalaburagi': 0.40, 'davangere': 0.32,
    'shimoga': 0.28, 'tumkur': 0.25, 'raichur': 0.38,
    'bidar': 0.35, 'hassan': 0.22, 'mandya': 0.25,
    'chikmagalur': 0.20, 'udupi': 0.18, 'kodagu': 0.15,
    'chitradurga': 0.30, 'koppal': 0.35, 'bagalkot': 0.32,
    'gadag': 0.28, 'haveri': 0.25, 'uttarakannada': 0.20,
    'chamarajanagar': 0.25, 'yadgir': 0.40,

    // ── Tamil Nadu ──────────────────────────────────────────────────────────
    'chennai': 0.38, 'coimbatore': 0.30, 'madurai': 0.32,
    'tiruchirappalli': 0.28, 'trichy': 0.28, 'salem': 0.30,
    'tirunelveli': 0.25, 'erode': 0.25, 'vellore': 0.28,
    'thoothukudi': 0.30, 'thanjavur': 0.22, 'dindigul': 0.25,
    'cuddalore': 0.30, 'kanchipuram': 0.32, 'tiruvallur': 0.30,
    'villupuram': 0.28, 'tiruvarur': 0.20, 'nagapattinam': 0.22,
    'ramanathapuram': 0.28, 'sivaganga': 0.22, 'virudhunagar': 0.25,
    'theni': 0.22, 'namakkal': 0.25, 'karur': 0.22,
    'tiruppur': 0.28, 'nilgiris': 0.20, 'krishnagiri': 0.30,
    'dharmapuri': 0.28, 'perambalur': 0.18, 'ariyalur': 0.20,
    'pudukkottai': 0.22,

    // ── Telangana ───────────────────────────────────────────────────────────
    'hyderabad': 0.42, 'warangal': 0.35, 'nizamabad': 0.32,
    'karimnagar': 0.30, 'khammam': 0.33, 'nalgonda': 0.30,
    'mahbubnagar': 0.35, 'adilabad': 0.38, 'medak': 0.28,
    'rangareddy': 0.38, 'sangareddy': 0.30, 'siddipet': 0.28,
    'jagtiyal': 0.30, 'peddapalli': 0.32, 'mancherial': 0.35,
    'kamareddy': 0.28, 'rajanna': 0.30, 'medchal': 0.35,
    'vikarabad': 0.28, 'wanaparthy': 0.25, 'nagarkurnool': 0.28,
    'suryapet': 0.30, 'yadadri': 0.25, 'jayashankar': 0.30,
    'jangaon': 0.25, 'mahabubabad': 0.28, 'bhadradri': 0.32,

    // ── Bihar ───────────────────────────────────────────────────────────────
    'patna': 0.45, 'gaya': 0.38, 'muzaffarpur': 0.35,
    'bhagalpur': 0.38, 'darbhanga': 0.30, 'purnia': 0.32,
    'begusarai': 0.40, 'samastipur': 0.32, 'munger': 0.35,
    'chapra': 0.30, 'arrah': 0.28, 'katihar': 0.30,
    'nalanda': 0.25, 'buxar': 0.28, 'rohtas': 0.30,
    'aurangabadbh': 0.35,
    'nawada': 0.28, 'jehanabad': 0.35, 'vaishali': 0.28,
    'siwan': 0.25, 'gopalganj': 0.25, 'saran': 0.28,
    'madhubani': 0.22, 'sitamarhi': 0.25, 'sheohar': 0.20,
    'eastchamparan': 0.28, 'westchamparan': 0.25,
    'saharsa': 0.28, 'supaul': 0.22, 'madhepura': 0.25,
    'kishanganj': 0.20, 'araria': 0.25, 'banka': 0.28,
    'jamui': 0.30, 'lakhisarai': 0.25, 'sheikhpura': 0.22,
    'khagaria': 0.25,

    // ── Jharkhand ───────────────────────────────────────────────────────────
    'ranchi': 0.42, 'jamshedpur': 0.38, 'dhanbad': 0.45,
    'bokaro': 0.40, 'deoghar': 0.32, 'hazaribagh': 0.38,
    'giridih': 0.35, 'ramgarh': 0.38, 'dumka': 0.30,
    'palamu': 0.42, 'chatra': 0.35, 'koderma': 0.30,
    'gumla': 0.35, 'lohardaga': 0.30, 'simdega': 0.28,
    'westsinghbhum': 0.40, 'eastsinghbhum': 0.38,
    'seraikela': 0.32, 'sahebganj': 0.28, 'pakur': 0.25,
    'godda': 0.28, 'jamtara': 0.30, 'latehar': 0.35,
    'khunti': 0.32,

    // ── Odisha ──────────────────────────────────────────────────────────────
    'bhubaneswar': 0.38, 'cuttack': 0.35, 'berhampur': 0.32,
    'rourkela': 0.35, 'sambalpur': 0.30, 'balasore': 0.28,
    'puri': 0.32, 'bhadrak': 0.25, 'baripada': 0.30,
    'jharsuguda': 0.32, 'angul': 0.30, 'dhenkanal': 0.25,
    'jajpur': 0.28, 'kendrapara': 0.22, 'jagatsinghpur': 0.25,
    'khordha': 0.35, 'nayagarh': 0.22, 'ganjam': 0.32,
    'gajapati': 0.28, 'rayagada': 0.35, 'koraput': 0.40,
    'malkangiri': 0.45, 'nabarangpur': 0.38, 'kalahandi': 0.35,
    'nuapada': 0.30, 'bolangir': 0.32, 'sonepur': 0.25,
    'bargarh': 0.28, 'sundargarh': 0.35, 'keonjhar': 0.32,
    'mayurbhanj': 0.30,

    // ── West Bengal ─────────────────────────────────────────────────────────
    'kolkata': 0.38, 'howrah': 0.35, 'asansol': 0.32,
    'siliguri': 0.30, 'durgapur': 0.28, 'bardhaman': 0.30,
    'midnapore': 0.28, 'kharagpur': 0.25,

    // ── Gujarat ─────────────────────────────────────────────────────────────
    'ahmedabad': 0.38, 'surat': 0.32, 'vadodara': 0.30,
    'rajkot': 0.28, 'gandhinagar': 0.22, 'jamnagar': 0.28,
    'bhavnagar': 0.25, 'junagadh': 0.25,

    // ── Kerala ──────────────────────────────────────────────────────────────
    'thiruvananthapuram': 0.48, 'kochi': 0.45, 'kozhikode': 0.42,
    'thrissur': 0.40, 'kollam': 0.45, 'palakkad': 0.38,
    'alappuzha': 0.40, 'kannur': 0.42, 'malappuram': 0.38,
    'kottayam': 0.35, 'ernakulam': 0.42, 'idukki': 0.30,
    'wayanad': 0.32, 'kasaragod': 0.35,

    // ── Punjab ──────────────────────────────────────────────────────────────
    'chandigarh': 0.35, 'ludhiana': 0.32, 'amritsar': 0.30,
    'jalandhar': 0.28, 'patiala': 0.28, 'bathinda': 0.25,

    // ── Haryana ─────────────────────────────────────────────────────────────
    'gurgaon': 0.45, 'gurugram': 0.45, 'faridabad': 0.42,
    'panipat': 0.38, 'ambala': 0.32, 'karnal': 0.30,
    'rohtak': 0.35, 'hisar': 0.38,
  };
}
