#ifndef WIZQTCOMPAT_H
#define WIZQTCOMPAT_H

#include <QtGlobal>

#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
#  include <QtCore5Compat/QRegExp>
#  include <QtCore5Compat/QTextCodec>
#else
#  include <QRegExp>
#  include <QTextCodec>
#endif

#endif // WIZQTCOMPAT_H
