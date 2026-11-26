// =============================================================================
//  TokenStore — armazenamento seguro do refresh token no cofre do SO
// =============================================================================
//  No Windows usa o Gerenciador de Credenciais nativo (CredWriteW/CredReadW/
//  CredDeleteW), evitando gravar tokens em texto puro (RNF-L01).
//  Em outros SOs, mantem apenas em memoria ate integracao com Secret Service /
//  Keychain (QtKeychain).
// =============================================================================
#pragma once

#include <QString>

class TokenStore
{
public:
    static bool saveRefreshToken(const QString &token);
    static QString loadRefreshToken();
    static void clearRefreshToken();
};
