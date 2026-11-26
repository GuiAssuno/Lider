#include "TokenStore.h"

#ifdef Q_OS_WIN
#include <windows.h>
#include <wincred.h>

namespace {
const wchar_t *kTargetName = L"LiderLauncher/refresh_token";
const wchar_t *kUserName = L"lider_session";
}

bool TokenStore::saveRefreshToken(const QString &token)
{
    if (token.isEmpty()) {
        clearRefreshToken();
        return true;
    }

    const QByteArray utf8 = token.toUtf8();
    CREDENTIALW cred{};
    cred.Type = CRED_TYPE_GENERIC;
    cred.TargetName = const_cast<LPWSTR>(kTargetName);
    cred.UserName = const_cast<LPWSTR>(kUserName);
    cred.CredentialBlobSize = static_cast<DWORD>(utf8.size());
    cred.CredentialBlob = reinterpret_cast<LPBYTE>(const_cast<char *>(utf8.constData()));
    cred.Persist = CRED_PERSIST_LOCAL_MACHINE;

    return CredWriteW(&cred, 0) == TRUE;
}

QString TokenStore::loadRefreshToken()
{
    PCREDENTIALW cred = nullptr;
    if (!CredReadW(kTargetName, CRED_TYPE_GENERIC, 0, &cred) || !cred)
        return {};

    QString token;
    if (cred->CredentialBlob && cred->CredentialBlobSize > 0) {
        token = QString::fromUtf8(
            reinterpret_cast<const char *>(cred->CredentialBlob),
            static_cast<int>(cred->CredentialBlobSize));
    }
    CredFree(cred);
    return token;
}

void TokenStore::clearRefreshToken()
{
    CredDeleteW(kTargetName, CRED_TYPE_GENERIC, 0);
}

#else

namespace {
QString g_fallbackToken;
}

bool TokenStore::saveRefreshToken(const QString &token)
{
    g_fallbackToken = token;
    return true;
}

QString TokenStore::loadRefreshToken()
{
    return g_fallbackToken;
}

void TokenStore::clearRefreshToken()
{
    g_fallbackToken.clear();
}

#endif
