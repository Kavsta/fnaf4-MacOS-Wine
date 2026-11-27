/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/.
 */

// Add standard window chrome while preserving the game's client size.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <wchar.h>

typedef struct {
    const wchar_t *exe;
    HWND window;
} WindowSearch;

static BOOL CALLBACK find_game_window(HWND window, LPARAM context)
{
    WindowSearch *search = (WindowSearch *)context;
    wchar_t title[128];
    static const wchar_t fnaf_title[] = L"Five Nights at Freddy";
    static const wchar_t ucn_title[] = L"Ultimate Custom Night";
    if (!IsWindowVisible(window) || !GetWindowTextW(window, title, ARRAYSIZE(title))) {
        return TRUE;
    }
    if (wcsncmp(title, fnaf_title, ARRAYSIZE(fnaf_title) - 1) != 0 &&
        wcsncmp(title, ucn_title, ARRAYSIZE(ucn_title) - 1) != 0) {
        return TRUE;
    }
    DWORD process_id;
    GetWindowThreadProcessId(window, &process_id);
    HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, process_id);
    if (!process) {
        return TRUE;
    }
    wchar_t path[2048];
    DWORD length = ARRAYSIZE(path);
    BOOL found = QueryFullProcessImageNameW(process, 0, path, &length);
    CloseHandle(process);
    if (!found) {
        return TRUE;
    }
    const wchar_t *base = wcsrchr(path, L'\\');
    if (_wcsicmp(base ? base + 1 : path, search->exe) != 0) {
        return TRUE;
    }
    search->window = window;
    return FALSE;
}

static int add_frame(HWND window, LONG desired_width, LONG desired_height)
{
    RECT current_client;
    if (!GetClientRect(window, &current_client)) {
        return 1;
    }
    LONG client_width = desired_width > 0 ? desired_width : current_client.right - current_client.left;
    LONG client_height = desired_height > 0 ? desired_height : current_client.bottom - current_client.top;

    const LONG old_style = GetWindowLongW(window, GWL_STYLE);
    const LONG chrome = WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX |
                        WS_MAXIMIZEBOX | WS_THICKFRAME;
    const LONG style = (old_style & ~(LONG)WS_POPUP) | chrome;
    if (style == old_style) {
        puts("Window already has standard controls.");
        return 0;
    }

    RECT bounds = {0, 0, client_width, client_height};
    const DWORD ex_style = GetWindowLongW(window, GWL_EXSTYLE);
    if (!AdjustWindowRectEx(&bounds, style, GetMenu(window) != NULL, ex_style)) {
        return 1;
    }

    if (style != old_style) {
        SetLastError(ERROR_SUCCESS);
        if (!SetWindowLongW(window, GWL_STYLE, style) && GetLastError() != ERROR_SUCCESS) {
            return 1;
        }
    }
    LONG screen_width = GetSystemMetrics(SM_CXSCREEN);
    LONG screen_height = GetSystemMetrics(SM_CYSCREEN);
    LONG window_width = bounds.right - bounds.left;
    LONG window_height = bounds.bottom - bounds.top;
    LONG x = screen_width > window_width ? (screen_width - window_width) / 2 : 0;
    LONG y = screen_height > window_height ? (screen_height - window_height) / 2 : 0;
    const UINT flags = SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED;
    if (!SetWindowPos(window, NULL, x, y, window_width, window_height, flags)) {
        const DWORD error = GetLastError();
        SetWindowLongW(window, GWL_STYLE, old_style);
        SetLastError(error);
        return 1;
    }
    printf("Enabled resize/fullscreen controls (client %ld x %ld).\n", client_width, client_height);
    return 0;
}

static BOOL parse_size(const wchar_t *text, LONG *value)
{
    wchar_t *end = NULL;
    long parsed = wcstol(text, &end, 10);
    if (!text[0] || !end || *end || parsed < 1 || parsed > 32768) return FALSE;
    *value = (LONG)parsed;
    return TRUE;
}

int wmain(int argc, wchar_t **argv)
{
    if (argc != 2 && argc != 4) {
        fputs("Usage: window-frame.exe <target filename> [client width client height]\n", stderr);
        return 2;
    }
    LONG desired_width = 0;
    LONG desired_height = 0;
    if (argc == 4 && (!parse_size(argv[2], &desired_width) || !parse_size(argv[3], &desired_height))) {
        fputs("Client dimensions must be positive integers.\n", stderr);
        return 2;
    }
    WindowSearch search = {argv[1], NULL};
    for (int attempt = 0; attempt < 120; ++attempt) {
        EnumWindows(find_game_window, (LPARAM)&search);
        if (search.window) {
            const int result = add_frame(search.window, desired_width, desired_height);
            if (result) {
                fprintf(stderr, "Could not add a window frame (Win32 error %lu).\n", GetLastError());
            }
            return result;
        }
        Sleep(250);
    }
    fputs("The game window did not appear within 30 seconds.\n", stderr);
    return 2;
}
