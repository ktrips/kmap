/**
 * iOSアプリの表示用バージョン（MARKETING_VERSION・ビルド番号）。
 *
 * Web側はXcodeのビルド成果物を直接参照できないため、iOSアプリをApp Store Connectへ
 * アップロードしてバージョン・ビルド番号を上げた際は、ここも手動で合わせて更新すること。
 * iOSアプリ側（設定画面の「このアプリについて」）は、Bundle.main.infoDictionaryから
 * 実際のビルドの値を動的に読むため、常に実態と一致する。
 */
export const IOS_APP_VERSION = "1.0 (22)";
