/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/.
 */

// Add standard window chrome while preserving the game's client size.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <wchar.h>

typedef struct {
    const wchar_t *exe;
    HWND window;
} WindowSearch;

static BOOL CALLBACK find_game_window(HWND window, LPARAM context)
{
    WindowSearch *search = (WindowSearch *)context;
    wchar_t title[128];
    static const wchar_t game_title[] = L"Five Nights at Freddy";
    if (!IsWindowVisible(window) || !GetWindowTextW(window, title, ARRAYSIZE(title))) {
        return TRUE;
    }
    if (wcsncmp(title, game_title, ARRAYSIZE(game_title) - 1) != 0) {
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

static int add_frame(HWND window)
{
    RECT client;
    if (!GetClientRect(window, &client)) {
        return 1;
    }

    const LONG old_style = GetWindowLongW(window, GWL_STYLE);
    const LONG chrome = WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX |
                        WS_MAXIMIZEBOX | WS_THICKFRAME;
    const LONG style = (old_style & ~(LONG)WS_POPUP) | chrome;
    if (style == old_style) {
        puts("Window already has standard controls.");
        return 0;
    }

    RECT bounds = client;
    const DWORD ex_style = GetWindowLongW(window, GWL_EXSTYLE);
    if (!AdjustWindowRectEx(&bounds, style, GetMenu(window) != NULL, ex_style)) {
        return 1;
    }

    SetLastError(ERROR_SUCCESS);
    if (!SetWindowLongW(window, GWL_STYLE, style) && GetLastError() != ERROR_SUCCESS) {
        return 1;
    }
    const UINT flags = SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED;
    if (!SetWindowPos(window, NULL, 0, 0, bounds.right - bounds.left,
                      bounds.bottom - bounds.top, flags)) {
        const DWORD error = GetLastError();
        SetWindowLongW(window, GWL_STYLE, old_style);
        SetWindowPos(window, NULL, 0, 0, 0, 0, flags | SWP_NOSIZE);
        SetLastError(error);
        return 1;
    }
    printf("Enabled resize and fullscreen controls (client %ld x %ld).\n",
           client.right - client.left, client.bottom - client.top);
    return 0;
}

int wmain(int argc, wchar_t **argv)
{
    if (argc != 2) {
        fputs("Usage: window-frame.exe <target filename>\n", stderr);
        return 2;
    }
    WindowSearch search = {argv[1], NULL};
    for (int attempt = 0; attempt < 120; ++attempt) {
        EnumWindows(find_game_window, (LPARAM)&search);
        if (search.window) {
            const int result = add_frame(search.window);
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
