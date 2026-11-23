// =============================================================================
//  BaseController — base comum dos controllers (ViewModels) expostos ao QML
// =============================================================================
//  Oferece estado padrão de UI (`loading`, `error`) e acesso ao backend.
//  Novos módulos (ex.: "Histórico") só precisam herdar desta classe.
// =============================================================================
#pragma once

#include <QObject>
#include <QString>
#include "core/IBackendService.h"

class BaseController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
public:
    explicit BaseController(IBackendService *backend, QObject *parent = nullptr)
        : QObject(parent), m_backend(backend) {}

    bool loading() const { return m_loading; }
    QString error() const { return m_error; }

signals:
    void loadingChanged();
    void errorChanged();

protected:
    IBackendService *backend() const { return m_backend; }

    void setLoading(bool v) { if (m_loading != v) { m_loading = v; emit loadingChanged(); } }
    void setError(const QString &e) { if (m_error != e) { m_error = e; emit errorChanged(); } }

private:
    IBackendService *m_backend;   // não-proprietário (vida gerida pelo main)
    bool m_loading = false;
    QString m_error;
};
