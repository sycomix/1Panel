import { useTheme } from '@/hooks/use-theme';
import { GlobalStore } from '@/store';
const globalStore = GlobalStore();
const { switchTheme } = useTheme();

export function resetXSetting() {
    globalStore.themeConfig.title = '';
    globalStore.themeConfig.logo = '';
    globalStore.themeConfig.logoWithText = '';
    globalStore.themeConfig.favicon = '';
}

export function initFavicon() {
    document.title = globalStore.themeConfig.panelName;
    let favicon = globalStore.themeConfig.favicon;
    const link = (document.querySelector("link[rel*='icon']") || document.createElement('link')) as HTMLLinkElement;
    link.type = 'image/x-icon';
    link.rel = 'shortcut icon';
    link.href = favicon ? `/api/v2/images/favicon?t=${Date.now()}` : '/public/favicon.png';
    document.head.appendChild(link);
}

export async function getXpackSetting() {
    let searchXSetting;
    const xpackModules = import.meta.glob('../xpack/api/modules/setting.ts', { eager: true });
    if (xpackModules['../xpack/api/modules/setting.ts']) {
        searchXSetting = xpackModules['../xpack/api/modules/setting.ts']['searchXSetting'] || {};
        const res = await searchXSetting();
        if (!res) {
            initFavicon();
            resetXSetting();
            return;
        }
        initFavicon();
        return res;
    }
}

export async function getXpackSettingForTheme() {
    let searchXSetting;
    const xpackModules = import.meta.glob('../xpack/api/modules/setting.ts', { eager: true });
    if (xpackModules['../xpack/api/modules/setting.ts']) {
        searchXSetting = xpackModules['../xpack/api/modules/setting.ts']['searchXSetting'] || {};
        const res2 = await searchXSetting();
        if (res2) {
            globalStore.themeConfig.title = res2.data?.title;
            globalStore.themeConfig.logo = res2.data?.logo;
            globalStore.themeConfig.logoWithText = res2.data?.logoWithText;
            globalStore.themeConfig.favicon = res2.data?.favicon;
            globalStore.themeConfig.themeColor = res2.data?.themeColor;
            globalStore.themeConfig.theme = res2.data?.theme || 'auto';
        } else {
            resetXSetting();
        }
    }
    switchTheme();
    initFavicon();
}

export async function updateXpackSettingByKey(key: string, value: string) {
    let updateXSettingByKey;
    const xpackModules = import.meta.glob('../xpack/api/modules/setting.ts', { eager: true });
    if (xpackModules['../xpack/api/modules/setting.ts']) {
        updateXSettingByKey = xpackModules['../xpack/api/modules/setting.ts']['updateXSettingByKey'] || {};
        return updateXSettingByKey(key, value);
    }
}
