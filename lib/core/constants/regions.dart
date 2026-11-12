/// Countries offered in the app. Holiday data ships for India only for now.
const Map<String, String> supportedCountries = {
  'IN': 'India',
  'US': 'United States',
  'GB': 'United Kingdom',
  'SG': 'Singapore',
  'AE': 'United Arab Emirates',
  'AU': 'Australia',
};

/// Countries whose holiday dataset ships with the app.
const Set<String> countriesWithHolidayData = {'IN'};

/// Indian states and union territories, keyed by ISO 3166-2:IN code.
const Map<String, String> indiaRegions = {
  'AN': 'Andaman and Nicobar Islands',
  'AP': 'Andhra Pradesh',
  'AR': 'Arunachal Pradesh',
  'AS': 'Assam',
  'BR': 'Bihar',
  'CH': 'Chandigarh',
  'CG': 'Chhattisgarh',
  'DH': 'Dadra and Nagar Haveli and Daman and Diu',
  'DL': 'Delhi',
  'GA': 'Goa',
  'GJ': 'Gujarat',
  'HR': 'Haryana',
  'HP': 'Himachal Pradesh',
  'JK': 'Jammu and Kashmir',
  'JH': 'Jharkhand',
  'KA': 'Karnataka',
  'KL': 'Kerala',
  'LA': 'Ladakh',
  'LD': 'Lakshadweep',
  'MP': 'Madhya Pradesh',
  'MH': 'Maharashtra',
  'MN': 'Manipur',
  'ML': 'Meghalaya',
  'MZ': 'Mizoram',
  'NL': 'Nagaland',
  'OD': 'Odisha',
  'PY': 'Puducherry',
  'PB': 'Punjab',
  'RJ': 'Rajasthan',
  'SK': 'Sikkim',
  'TN': 'Tamil Nadu',
  'TS': 'Telangana',
  'TR': 'Tripura',
  'UP': 'Uttar Pradesh',
  'UK': 'Uttarakhand',
  'WB': 'West Bengal',
};

const String appVersion = '0.1.0+1';
