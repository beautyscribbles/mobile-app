// source: https://github.com/WoodyWoodsta/react-native-slider/blob/master/index.d.ts

declare module 'cldr-compact-number' {
  type CompactFormat = (
    input: number,
    lang: string, // Changed 'en' to be more flexible
    localeData: any, // Changed null to any for flexibility
    options?: {
      significantDigits?: number;
      minimumFractionDigits?: number;
      maximumFractionDigits?: number;
      financialFormat?: boolean;
      threshold?: number;
      long?: boolean;
    },
  ) => string;

  const compactFormat: CompactFormat;

  export default compactFormat;
}
