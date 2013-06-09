/**
 * This file is part of OpTiMSoC-GUI.
 *
 * OpTiMSoC-GUI is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation, either version 3 of
 * the License, or (at your option) any later version.
 *
 * OpTiMSoC-GUI is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with OpTiMSoC. If not, see <http://www.gnu.org/licenses/>.
 *
 * =================================================================
 *
 * Driver for the simple message passing hardware.
 *
 * (c) 2012-2013 by the author(s)
 *
 * Author(s):
 *    Philipp Wagner, philipp.wagner@tum.de
 */

#ifndef COMPUTETILE_H
#define COMPUTETILE_H

#include "tile.h"

class ComputeTileItem;

class ComputeTile : public Tile
{
Q_OBJECT
public:
    explicit ComputeTile(int computeTileId, QObject *parent = 0);
    QString tileTypeName() const { return tr("compute tile"); };
    TileItem* componentItem();
    int getTileId();

signals:

public slots:

private:
    int m_computeTileId;

};

#endif // COMPUTETILE_H
