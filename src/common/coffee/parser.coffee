# The contents of this file are subject to the Common Public Attribution
# License Version 1.0 (the “License”); you may not use this file except in
# compliance with the License. You may obtain a copy of the License at
# http://1clickBOM.com/LICENSE. The License is based on the Mozilla Public
# License Version 1.1 but Sections 14 and 15 have been added to cover use of
# software over a computer network and provide for limited attribution for the
# Original Developer. In addition, Exhibit A has been modified to be consistent
# with Exhibit B.
#
# Software distributed under the License is distributed on an
# "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
# the License for the specific language governing rights and limitations under
# the License.
#
# The Original Code is 1clickBOM.
#
# The Original Developer is the Initial Developer. The Original Developer of
# the Original Code is Kaspar Emanuel.

retailer_aliases =
    'Farnell'     : 'Farnell'
    'FEC'         : 'Farnell'
    'Premier'     : 'Farnell'
    'Digikey'     : 'Digikey'
    'Digi-key'    : 'Digikey'
    'Mouser'      : 'Mouser'
    'RS'          : 'RS'
    'RSOnline'    : 'RS'
    'RS-Online'   : 'RS'
    'RS-Delivers' : 'RS'
    'RSDelivers'  : 'RS'
    'Radio Spares': 'RS'
    'RadioSpares' : 'RS'
    'Newark'      : 'Newark'

headings =
    'reference'  : 'comment'
    'references' : 'comment'
    'line-note'  : 'comment'
    'line note'  : 'comment'
    'comment'    : 'comment'
    'comments'   : 'comment'
    'qty'        : 'quantity'
    'quantity'   : 'quantity'

#a case insensitive match
lookup = (name, obj) ->
    for key of obj
        re = new RegExp(key, 'i')
        if name.match(re)
            return obj[key]
    #else
    return null

checkValidItems =  (items_incoming, invalid) ->
    items = []
    for item in items_incoming
        number = parseInt(item.quantity)
        if invalid.length > 10
            items = []
            break
        if isNaN(number)
            invalid.push {item:item, reason:'Quantity is not a number.'}
        else if number < 1
            invalid.push {item:item, reason:'Quantity is less than one'}
        else
            item.quantity = number
            r = lookup(item.retailer, retailer_aliases)
            if not r?
                invalid.push
                    item: item
                    reason: "Retailer '#{item.retailer}' is not known."
            else
                item.retailer = r
                if item.retailer != 'Digikey'
                    item.part = item.part.replace(/-/g, '')
                items.push(item)
    return {items, invalid}

parseSimple = (rows) ->
    items = []
    invalid = []
    for row, i in rows
        if row != ''
            cells = row.split('\t')
            item =
                comment  : cells[0]
                quantity : cells[1]
                retailer : cells[2]
                part     : cells[3]
                row      : i + 1
            if !item.quantity
                invalid.push {item:item, reason: 'Quantity is undefined.'}
            else if !item.retailer
                invalid.push {item:item, reason: 'Retailer is undefined.'}
            else if !item.part
                invalid.push {item:item, reason: 'Part number is undefined.'}
            else
                items.push(item)
    return {items, invalid}


parseNamed = (rows, heading_order, retailer_order) ->
    items = []
    invalid = []
    for row, i in rows
        if row != ''
            cells = row.split('\t')
            for retailer,r_index in retailer_order
                part = cells[r_index + 2]
                if part? && part != ''
                    item =
                        comment  : cells[heading_order.indexOf('comment')]
                        quantity : cells[heading_order.indexOf('quantity')]
                        retailer : retailer
                        part     : part
                        row      : i + 1
                    if !item.quantity
                        invalid.push
                            item:item
                            reason: 'Quantity is undefined.'
                    else
                        items.push(item)
    return {items, invalid}


hasNamedColumns = (cells) ->
    for cell in cells
        if lookup(cell, headings)?
            return true
    #else
    return false


getOrder = (cells) ->
    heading_order = []
    retailer_order = []
    for cell in cells
        heading = lookup(cell, headings)
        retailer = lookup(cell, retailer_aliases)
        if heading?
            heading_order.push(heading)
        else if retailer?
            retailer_order.push(retailer)
        else
            return {reason: "Unknown heading '#{cell}' for named column"}

    if heading_order.length != 2
        return {reason: 'You need a line-note and a quantity column'}
    else if retailer_order.length <= 0
        return {reason: 'You need at least on retailer'}
    else
        return {heading_order:heading_order, retailer_order:retailer_order}


parseTSV = (text) ->
    rows = text.split('\n')
    firstCells = rows[0].split('\t')
    if firstCells.length < 3 || firstCells.length > 7
        return {
            items:[]
            invalid:[{item: {row:1}, reason:'Invalid number of columns'}]
        }
    if hasNamedColumns(firstCells)
        {heading_order, retailer_order, reason} = getOrder(firstCells)
        if not (heading_order? && retailer_order?)
            return {
                items:[]
                invalid:[{item: {row:1}, reason:reason}]
            }
        {items, invalid} = parseNamed(rows[1..], heading_order, retailer_order)
    else
        {items, invalid} = parseSimple(rows)
    {items, invalid} = checkValidItems(items, invalid)
    return {items, invalid}


exports.parseTSV = parseTSV
