-- Source: https://en.wikipedia.org/wiki/Module:Citation/CS1
-- with adaptations by Antonin Delpeuch

function (sample, export_ustring_match, export_ustring_len, export_uri_encode, export_text_split, export_nowiki)
local z = {
    error_categories = {};      -- for categorizing citations that contain errors
    error_ids = {};
    message_tail = {};
    maintenance_cats = {};      -- for categorizing citations that aren't erroneous per se, but could use a little work
    properties_cats = {};       -- for categorizing citations based on certain properties, language of source for instance
}

--[[--------------------------< F O R W A R D   D E C L A R A T I O N S >--------------------------------------
]]

local p = {}
local global_content_language = 'en';
local current_page_title = 'Page';

--[[--------------------------< I S _ V A L I D _ A C C E S S D A T E >----------------------------------------

returns true if:
    Wikipedia start date <= accessdate < today + 2 days

Wikipedia start date is 2001-01-15T00:00:00 UTC which is 979516800 seconds after 1970-01-01T00:00:00 UTC (the start of Unix time)
accessdate is the date provided in |accessdate= at time 00:00:00 UTC
today is the current date at time 00:00:00 UTC plus 48 hours
    if today is 2015-01-01T00:00:00 then
        adding 24 hours gives 2015-01-02T00:00:00 – one second more than today
        adding 24 hours gives 2015-01-03T00:00:00 – one second more than tomorrow

]]

local function is_valid_accessdate (accessdate)
    local lang = global_content_language;
    local good1, good2;
    local access_ts, tomorrow_ts;                                               -- to hold unix time stamps representing the dates
        
    good1, access_ts = pcall( lang.formatDate, lang, 'U', accessdate );         -- convert accessdate value to unix timesatmp 
    good2, tomorrow_ts = pcall( lang.formatDate, lang, 'U', 'today + 2 days' ); -- today midnight + 2 days is one second more than all day tomorrow
    
    if good1 and good2 then
        access_ts = tonumber (access_ts);                                       -- convert to numbers for the comparison
        tomorrow_ts = tonumber (tomorrow_ts);
    else
        return false;                                                           -- one or both failed to convert to unix time stamp
    end
    
    if 979516800 <= access_ts and access_ts < tomorrow_ts then                  -- Wikipedia start date <= accessdate < tomorrow's date
        return true;
    else
        return false;                                                           -- accessdate out of range
    end
end

--[[--------------------------< G E T _ M O N T H _ N U M B E R >----------------------------------------------

returns a number according to the month in a date: 1 for January, etc.  Capitalization and spelling must be correct. If not a valid month, returns 0

]]

local function get_month_number (month)
local long_months = {['January']=1, ['February']=2, ['March']=3, ['April']=4, ['May']=5, ['June']=6, ['July']=7, ['August']=8, ['September']=9, ['October']=10, ['November']=11, ['December']=12};
local short_months = {['Jan']=1, ['Feb']=2, ['Mar']=3, ['Apr']=4, ['May']=5, ['Jun']=6, ['Jul']=7, ['Aug']=8, ['Sep']=9, ['Oct']=10, ['Nov']=11, ['Dec']=12};
local temp;
    temp=long_months[month];
    if temp then return temp; end               -- if month is the long-form name
    temp=short_months[month];
    if temp then return temp; end               -- if month is the short-form name
    return 0;                                   -- misspelled, improper case, or not a month name
end

--[[--------------------------< G E T _ S E A S O N _ N U M B E R >--------------------------------------------

returns a number according to the sequence of seasons in a year: 1 for Winter, etc.  Capitalization and spelling must be correct. If not a valid season, returns 0

]]

local function get_season_number (season)
local season_list = {['Winter']=21, ['Spring']=22, ['Summer']=23, ['Fall']=24, ['Autumn']=24};  -- make sure these numbers do not overlap month numbers
local temp;
    temp=season_list[season];
    if temp then return temp; end                                               -- if season is a valid name return its number
    return 0;                                                                   -- misspelled, improper case, or not a season name
end

--[[--------------------------< I S _ P R O P E R _ N A M E >--------------------------------------------------

returns a non-zero number if date contains a recognized proper name.  Capitalization and spelling must be correct.

]]

local function is_proper_name (name)
local name_list = {['Christmas']=31}
local temp;
    temp=name_list[name];
    if temp then return temp; end               -- if name is a valid name return its number
    return 0;                                   -- misspelled, improper case, or not a proper name
end

--[[--------------------------< I S _ V A L I D _ M O N T H _ O R _ S E A S O N >------------------------------

--returns true if month or season is valid (properly spelled, capitalized, abbreviated)

]]

local function is_valid_month_or_season (month_season)
    if 0 == get_month_number (month_season) then        -- if month text isn't one of the twelve months, might be a season
        if 0 == get_season_number (month_season) then   -- not a month, is it a season?
            return false;                               -- return false not a month or one of the five seasons
        end
    end
    return true;
end

--[[--------------------------< I S _ V A L I D _ Y E A R >----------------------------------------------------

Function gets current year from the server and compares it to year from a citation parameter.  Years more than one year in the future are not acceptable.

]]

local function is_valid_year(year)
    if not is_set(year_limit) then
        year_limit = tonumber(os.date("%Y"))+1;         -- global variable so we only have to fetch it once
    end
    return tonumber(year) <= year_limit;                -- false if year is in the future more than one year
end

--[[--------------------------< I S _ V A L I D _ D A T E >----------------------------------------------------
Returns true if day is less than or equal to the number of days in month and year is no farther into the future
than next year; else returns false.

Assumes Julian calendar prior to year 1582 and Gregorian calendar thereafter. Accounts for Julian calendar leap
years before 1582 and Gregorian leap years after 1582. Where the two calendars overlap (1582 to approximately
1923) dates are assumed to be Gregorian.

]]

local function is_valid_date (year, month, day)
local days_in_month = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
local month_length;
    if not is_valid_year(year) then                                             -- no farther into the future than next year
        return false;
    end
    
    month = tonumber(month);                                                    -- required for YYYY-MM-DD dates
    
    if (2==month) then                                                          -- if February
        month_length = 28;                                                      -- then 28 days unless
        if 1582 > tonumber(year) then                                           -- Julian calendar
            if 0==(year%4) then
                month_length = 29;
            end
        else                                                                    -- Gregorian calendar
            if (0==(year%4) and (0~=(year%100) or 0==(year%400))) then          -- is a leap year?
                month_length = 29;                                              -- if leap year then 29 days in February
            end
        end
    else
        month_length=days_in_month[month];
    end

    if tonumber (day) > month_length then
        return false;
    end
    return true;
end

--[[--------------------------< I S _ V A L I D _ M O N T H _ R A N G E _ S T Y L E >--------------------------

Months in a range are expected to have the same style: Jan–Mar or October–December but not February–Mar or Jul–August. 
There is a special test for May because it can be either short or long form.

Returns true when style for both months is the same

]]

local function is_valid_month_range_style (month1, month2)
local len1 = month1:len();
local len2 = month2:len();
    if len1 == len2 then
        return true;                                                            -- both months are short form so return true
    elseif 'May' == month1 or 'May'== month2 then
        return true;                                                            -- both months are long form so return true
    elseif 3 == len1 or 3 == len2 then
        return false;                                                           -- months are mixed form so return false
    else
        return true;                                                            -- both months are long form so return true
    end
end


--[[--------------------------< I S _ V A L I D _ M O N T H _ S E A S O N _ R A N G E >------------------------

Check a pair of months or seasons to see if both are valid members of a month or season pair.

Month pairs are expected to be left to right, earliest to latest in time.

Similarly, seasons are also left to right, earliest to latest in time.  There is an oddity with seasons: winter is assigned a value of 1, spring 2, ...,
fall and autumn 4.  Because winter can follow fall/autumn at the end of a calender year, a special test is made to see if |date=Fall-Winter yyyy (4-1) is the date.

]]

local function is_valid_month_season_range(range_start, range_end)
    local range_start_number = get_month_number (range_start);
    
    if 0 == range_start_number then                                             -- is this a month range?
        local range_start_number = get_season_number (range_start);             -- not a month; is it a season? get start season number
        local range_end_number = get_season_number (range_end);                 -- get end season number

        if 0 ~= range_start_number then                                         -- is start of range a season?
            if range_start_number < range_end_number then                       -- range_start is a season
                return true;                                                    -- return true when range_end is also a season and follows start season; else false
            end
            if 24 == range_start_number and 21 == range_end_number then         -- special case when season range is Fall-Winter or Autumn-Winter
                return true;
            end
        end
        return false;       -- range_start is not a month or a season; or range_start is a season and range_end is not; or improper season sequence
    end

    local range_end_number = get_month_number (range_end);                      -- get end month number
    if range_start_number < range_end_number then                               -- range_start is a month; does range_start precede range_end?
        if is_valid_month_range_style (range_start, range_end) then             -- do months have the same style?
            return true;                                                        -- proper order and same style
        end
    end
    return false;                                                               -- range_start month number is greater than or equal to range end number; or range end isn't a month
end


--[[--------------------------< M A K E _ C O I N S _ D A T E >------------------------------------------------

This function receives a table of date parts for one or two dates and an empty table reference declared in
Module:Citation/CS1.  The function is called only for |date= parameters and only if the |date=<value> is 
determined to be a valid date format.  The question of what to do with invalid date formats is not answered here.

The date parts in the input table are converted to an ISO 8601 conforming date string:
    single whole dates:     yyyy-mm-dd
    month and year dates:   yyyy-mm
    year dates:             yyyy
    ranges:                 yyyy-mm-dd/yyyy-mm-dd
                            yyyy-mm/yyyy-mm
                            yyyy/yyyy

Dates in the Julian calendar are reduced to year or year/year so that we don't have to do calendar conversion from
Julian to Proleptic Gregorian.

The input table has:
    year, year2 – always present; if before 1582, ignore months and days if present
    month, month2 – 0 if not provided, 1-12 for months, 21-24 for seasons; 31– proper name dates
    day, day2 –  0 if not provided, 1-31 for days
    
the output table receives:
    rftdate:    an IS8601 formatted date
    rftchron:   a free-form version of the date, usually without year which is in rftdate (season ranges and propername dates)
    rftssn:     one of four season keywords: winter, spring, summer, fall (lowercase)

]]

local function make_COinS_date (input, tCOinS_date)
    local date;                                                                 -- one date or first date in a range
    local date2 = '';                                                           -- end of range date
    
    if 1582 > tonumber(input.year) or 20 < tonumber(input.month) then           -- Julian calendar or season so &rft.date gets year only
        date = input.year;
        if 0 ~= input.year2 and input.year ~= input.year2 then                  -- if a range, only the second year portion when not the same as range start year
            date = string.format ('%.4d/%.4d', tonumber(input.year), tonumber(input.year2))     -- assemble the date range
        end
        if 20 < tonumber(input.month) then                                      -- if season or propername date
            local season = {[21]='winter', [22]='spring', [23]='summer', [24]='fall', [31]='Christmas'};    -- seasons lowercase, no autumn; proper names use title case
            if 0 == input.month2 then                                           -- single season date
                if 30 <tonumber(input.month) then
                    tCOinS_date.rftchron = season[input.month];                 -- proper name dates
                else
                    tCOinS_date.rftssn = season[input.month];                   -- seasons
                end
            else                                                                -- season range with a second season specified
                if input.year ~= input.year2 then                               -- season year – season year range or season year–year
                    tCOinS_date.rftssn = season[input.month];                   -- start of range season; keep this?
                    if 0~= month2 then
                        tCOinS_date.rftchron = string.format ('%s %s – %s %s', season[input.month], input.year, season[input.month2], input.year2);
                    end
                else                                                            -- season–season year range
                    tCOinS_date.rftssn = season[input.month];                   -- start of range season; keep this?
                    tCOinS_date.rftchron = season[input.month] .. '–' .. season[input.month2];  -- season–season year range
                end
            end
        end
        tCOinS_date.rftdate = date;
        return;                                                                 -- done
    end
    
    if 0 ~= input.day then
        date = string.format ('%s-%.2d-%.2d', input.year, tonumber(input.month), tonumber(input.day));  -- whole date
    elseif 0 ~= input.month then
        date = string.format ('%s-%.2d', input.year, tonumber(input.month));    -- year and month
    else
        date = string.format ('%s', input.year);                                -- just year
    end

    if 0 ~= input.year2 then
        if 0 ~= input.day2 then
            date2 = string.format ('/%s-%.2d-%.2d', input.year2, tonumber(input.month2), tonumber(input.day2));     -- whole date
        elseif 0 ~= input.month2 then
            date2 = string.format ('/%s-%.2d', input.year2, tonumber(input.month2));    -- year and month
        else
            date2 = string.format ('/%s', input.year2);                         -- just year
        end
    end
    
    tCOinS_date.rftdate = date .. date2;                                        -- date2 has the '/' separator
    return;
end


--[[--------------------------< C H E C K _ D A T E >----------------------------------------------------------

Check date format to see that it is one of the formats approved by WP:DATESNO or WP:DATERANGE. Exception: only
allowed range separator is endash.  Additionally, check the date to see that it is a real date: no 31 in 30-day
months; no 29 February when not a leap year.  Months, both long-form and three character abbreviations, and seasons
must be spelled correctly.  Future years beyond next year are not allowed.

If the date fails the format tests, this function returns false and does not return values for anchor_year and
COinS_date.  When this happens, the date parameter is used in the COinS metadata and the CITEREF identifier gets
its year from the year parameter if present otherwise CITEREF does not get a date value.

Inputs:
    date_string - date string from date-holding parameters (date, year, accessdate, embargo, archivedate, etc.)

Returns:
    false if date string is not a real date; else
    true, anchor_year, COinS_date
        anchor_year can be used in CITEREF anchors
        COinS_date is ISO 8601 format date; see make_COInS_date()

]]

local function check_date (date_string, tCOinS_date)
    local year;         -- assume that year2, months, and days are not used;
    local year2=0;      -- second year in a year range
    local month=0;
    local month2=0;     -- second month in a month range
    local day=0;
    local day2=0;       -- second day in a day range
    local anchor_year;
    local coins_date;

    if date_string:match("^%d%d%d%d%-%d%d%-%d%d$") then                                     -- year-initial numerical year month day format
        year, month, day=string.match(date_string, "(%d%d%d%d)%-(%d%d)%-(%d%d)");
        if 12 < tonumber(month) or 1 > tonumber(month) or 1583 > tonumber(year) then return false; end          -- month number not valid or not Gregorian calendar
        anchor_year = year;

    elseif date_string:match("^%a+ +[1-9]%d?, +[1-9]%d%d%d%a?$") then                       -- month-initial: month day, year
        month, day, anchor_year, year=string.match(date_string, "(%a+)%s*(%d%d?),%s*((%d%d%d%d)%a?)");
        month = get_month_number (month);
        if 0 == month then return false; end                                                -- return false if month text isn't one of the twelve months
                
    elseif date_string:match("^%a+ +[1-9]%d?–[1-9]%d?, +[1-9]%d%d%d%a?$") then              -- month-initial day range: month day–day, year; days are separated by endash
        month, day, day2, anchor_year, year=string.match(date_string, "(%a+) +(%d%d?)–(%d%d?), +((%d%d%d%d)%a?)");
        if tonumber(day) >= tonumber(day2) then return false; end                           -- date range order is left to right: earlier to later; dates may not be the same;
        month = get_month_number (month);
        if 0 == month then return false; end                                                -- return false if month text isn't one of the twelve months
        month2=month;                                                                       -- for metadata
        year2=year;

    elseif date_string:match("^[1-9]%d? +%a+ +[1-9]%d%d%d%a?$") then                        -- day-initial: day month year
        day, month, anchor_year, year=string.match(date_string, "(%d%d*)%s*(%a+)%s*((%d%d%d%d)%a?)");
        month = get_month_number (month);
        if 0 == month then return false; end                                                -- return false if month text isn't one of the twelve months

    elseif date_string:match("^[1-9]%d?–[1-9]%d? +%a+ +[1-9]%d%d%d%a?$") then               -- day-range-initial: day–day month year; days are separated by endash
        day, day2, month, anchor_year, year=string.match(date_string, "(%d%d?)–(%d%d?) +(%a+) +((%d%d%d%d)%a?)");
        if tonumber(day) >= tonumber(day2) then return false; end                           -- date range order is left to right: earlier to later; dates may not be the same;
        month = get_month_number (month);
        if 0 == month then return false; end                                                -- return false if month text isn't one of the twelve months
        month2=month;                                                                       -- for metadata
        year2=year;

    elseif date_string:match("^[1-9]%d? +%a+ – [1-9]%d? +%a+ +[1-9]%d%d%d%a?$") then        -- day initial month-day-range: day month - day month year; uses spaced endash
        day, month, day2, month2, anchor_year, year=date_string:match("(%d%d?) +(%a+) – (%d%d?) +(%a+) +((%d%d%d%d)%a?)");
        if (not is_valid_month_season_range(month, month2)) or not is_valid_year(year) then return false; end   -- date range order is left to right: earlier to later;
        month = get_month_number (month);                                                   -- for metadata
        month2 = get_month_number (month2);
        year2=year;

    elseif date_string:match("^%a+ +[1-9]%d? – %a+ +[1-9]%d?, +[1-9]%d%d%d?%a?$") then      -- month initial month-day-range: month day – month day, year;  uses spaced endash
        month, day, month2, day2, anchor_year, year=date_string:match("(%a+) +(%d%d?) – (%a+) +(%d%d?), +((%d%d%d%d)%a?)");
        if (not is_valid_month_season_range(month, month2)) or not is_valid_year(year) then return false; end
        month = get_month_number (month);                                                   -- for metadata
        month2 = get_month_number (month2);
        year2=year;

    elseif date_string:match("^[1-9]%d? +%a+ +[1-9]%d%d%d – [1-9]%d? +%a+ +[1-9]%d%d%d%a?$") then       -- day initial month-day-year-range: day month year - day month year; uses spaced endash
        day, month, year, day2, month2, anchor_year, year2=date_string:match("(%d%d?) +(%a+) +(%d%d%d%d?) – (%d%d?) +(%a+) +((%d%d%d%d?)%a?)");
        if tonumber(year2) <= tonumber(year) then return false; end                                             -- must be sequential years, left to right, earlier to later
        if not is_valid_year(year2) or not is_valid_month_range_style(month, month2) then return false; end     -- year2 no more than one year in the future; months same style
        month = get_month_number (month);                                                                       -- for metadata
        month2 = get_month_number (month2);

    elseif date_string:match("^%a+ +[1-9]%d?, +[1-9]%d%d%d – %a+ +[1-9]%d?, +[1-9]%d%d%d%a?$") then     -- month initial month-day-year-range: month day, year – month day, year;  uses spaced endash
        month, day, year, month2, day2, anchor_year, year2=date_string:match("(%a+) +(%d%d?), +(%d%d%d%d) – (%a+) +(%d%d?), +((%d%d%d%d)%a?)");
        if tonumber(year2) <= tonumber(year) then return false; end                                             -- must be sequential years, left to right, earlier to later
        if not is_valid_year(year2) or not is_valid_month_range_style(month, month2) then return false; end     -- year2 no more than one year in the future; months same style
        month = get_month_number (month);                                                                       -- for metadata
        month2 = get_month_number (month2);

    elseif date_string:match("^%a+ +[1-9]%d%d%d–%d%d%a?$") then                             -- special case Winter/Summer year-year (YYYY-YY); year separated with unspaced endash
        local century;
        month, year, century, anchor_year, year2=date_string:match("(%a+) +((%d%d)%d%d)–((%d%d)%a?)");
        if 'Winter' ~= month and 'Summer' ~= month then return false end;                   -- 'month' can only be Winter or Summer
        anchor_year=year..'–'..anchor_year;                                                 -- assemble anchor_year from both years
        year2 = century..year2;                                                             -- add the century to year2 for comparisons
        if 1 ~= tonumber(year2) - tonumber(year) then return false; end                     -- must be sequential years, left to right, earlier to later
        if not is_valid_year(year2) then return false; end                                  -- no year farther in the future than next year
        month = get_season_number (month);

    elseif date_string:match("^%a+ +[1-9]%d%d%d–[1-9]%d%d%d%a?$") then                      -- special case Winter/Summer year-year; year separated with unspaced endash
        month, year, anchor_year, year2=date_string:match("(%a+) +(%d%d%d%d)–((%d%d%d%d)%a?)");
        if 'Winter' ~= month and 'Summer' ~= month then return false end;                   -- 'month' can only be Winter or Summer
        anchor_year=year..'–'..anchor_year;                                                 -- assemble anchor_year from both years
        if 1 ~= tonumber(year2) - tonumber(year) then return false; end                     -- must be sequential years, left to right, earlier to later
        if not is_valid_year(year2) then return false; end                                  -- no year farther in the future than next year
        month = get_season_number (month);                                                  -- for metadata

    elseif date_string:match("^%a+ +[1-9]%d%d%d% – %a+ +[1-9]%d%d%d%a?$") then              -- month/season year - month/season year; separated by spaced endash
        month, year, month2, anchor_year, year2=date_string:match("(%a+) +(%d%d%d%d) – (%a+) +((%d%d%d%d)%a?)");
        anchor_year=year..'–'..anchor_year;                                                 -- assemble anchor_year from both years
        if tonumber(year) >= tonumber(year2) then return false; end                         -- left to right, earlier to later, not the same
        if not is_valid_year(year2) then return false; end                                  -- no year farther in the future than next year
        if 0 ~= get_month_number(month) and 0 ~= get_month_number(month2) and is_valid_month_range_style(month, month2) then    -- both must be month year, same month style
            month = get_month_number(month);
            month2 = get_month_number(month2);
        elseif 0 ~= get_season_number(month) and 0 ~= get_season_number(month2) then        -- both must be or season year, not mixed
            month = get_season_number(month);
            month2 = get_season_number(month2);
        else
             return false;
        end

    elseif date_string:match ("^%a+–%a+ +[1-9]%d%d%d%a?$") then                 -- month/season range year; months separated by endash 
        month, month2, anchor_year, year=date_string:match ("(%a+)–(%a+)%s*((%d%d%d%d)%a?)");
        if (not is_valid_month_season_range(month, month2)) or (not is_valid_year(year)) then return false; end
        if 0 ~= get_month_number(month) then                                    -- determined to be a valid range so just check this one to know if month or season
            month = get_month_number(month);
            month2 = get_month_number(month2);
        else
            month = get_season_number(month);
            month2 = get_season_number(month2);
        end
        year2=year;
        
    elseif date_string:match("^%a+ +%d%d%d%d%a?$") then                         -- month/season year or proper-name year
        month, anchor_year, year=date_string:match("(%a+)%s*((%d%d%d%d)%a?)");
        if not is_valid_year(year) then return false; end
        if not is_valid_month_or_season (month) and 0 == is_proper_name (month) then return false; end
        if 0 ~= get_month_number(month) then                                    -- determined to be a valid range so just check this one to know if month or season
            month = get_month_number(month);
        elseif 0 ~= get_season_number(month) then
            month = get_season_number(month);
        else
            month = is_proper_name (month);                                     -- must be proper name; not supported in COinS
        end

    elseif date_string:match("^[1-9]%d%d%d?–[1-9]%d%d%d?%a?$") then             -- Year range: YYY-YYY or YYY-YYYY or YYYY–YYYY; separated by unspaced endash; 100-9999
        year, anchor_year, year2=date_string:match("(%d%d%d%d?)–((%d%d%d%d?)%a?)");
        anchor_year=year..'–'..anchor_year;                                     -- assemble anchor year from both years
        if tonumber(year) >= tonumber(year2) then return false; end             -- left to right, earlier to later, not the same
        if not is_valid_year(year2) then return false; end                      -- no year farther in the future than next year

    elseif date_string:match("^[1-9]%d%d%d–%d%d%a?$") then                      -- Year range: YYYY–YY; separated by unspaced endash
        local century;
        year, century, anchor_year, year2=date_string:match("((%d%d)%d%d)–((%d%d)%a?)");
        anchor_year=year..'–'..anchor_year;                                     -- assemble anchor year from both years
        if 13 > tonumber(year2) then return false; end                          -- don't allow 2003-05 which might be May 2003
        year2 = century..year2;                                                 -- add the century to year2 for comparisons
        if tonumber(year) >= tonumber(year2) then return false; end             -- left to right, earlier to later, not the same
        if not is_valid_year(year2) then return false; end                      -- no year farther in the future than next year

    elseif date_string:match("^[1-9]%d%d%d?%a?$") then                          -- year; here accept either YYY or YYYY
        anchor_year, year=date_string:match("((%d%d%d%d?)%a?)");
        if false == is_valid_year(year) then
            return false;
        end

    else
        return false;                                                           -- date format not one of the MOS:DATE approved formats
    end

    local result=true;                                                          -- check whole dates for validity; assume true because not all dates will go through this test
    if 0 ~= year and 0 ~= month and 0 ~= day and 0 == year2 and 0 == month2 and 0 == day2 then      -- YMD (simple whole date)
        result=is_valid_date(year,month,day);

    elseif 0 ~= year and 0 ~= month and 0 ~= day and 0 == year2 and 0 == month2 and 0 ~= day2 then  -- YMD-d (day range)
        result=is_valid_date(year,month,day);
        result=result and is_valid_date(year,month,day2);

    elseif 0 ~= year and 0 ~= month and 0 ~= day and 0 == year2 and 0 ~= month2 and 0 ~= day2 then  -- YMD-md (day month range)
        result=is_valid_date(year,month,day);
        result=result and is_valid_date(year,month2,day2);

    elseif 0 ~= year and 0 ~= month and 0 ~= day and 0 ~= year2 and 0 ~= month2 and 0 ~= day2 then  -- YMD-ymd (day month year range)
        result=is_valid_date(year,month,day);
        result=result and is_valid_date(year2,month2,day2);
    end
    
    if false == result then return false; end

    if nil ~= tCOinS_date then                                                  -- this table only passed into this function when testing |date= parameter values
        make_COinS_date ({year=year, month=month, day=day, year2=year2, month2=month2, day2=day2}, tCOinS_date);    -- make an ISO 8601 date string for COinS
    end
    
    return true, anchor_year;                                                   -- format is good and date string represents a real date
end 


--[[--------------------------< D A T E S >--------------------------------------------------------------------

Cycle the date-holding parameters in passed table date_parameters_list through check_date() to check compliance with MOS:DATE. For all valid dates, check_date() returns
true. The |date= parameter test is unique, it is the only date holding parameter from which values for anchor_year (used in CITEREF identifiers) and COinS_date (used in
the COinS metadata) are derived.  The |date= parameter is the only date-holding parameter that is allowed to contain the no-date keywords "n.d." or "nd" (without quotes).

Unlike most error messages created in this module, only one error message is created by this function. Because all of the date holding parameters are processed serially,
a single error message is created as the dates are tested.

]]

local function dates(date_parameters_list, tCOinS_date)
    local anchor_year;      -- will return as nil if the date being tested is not |date=
    local COinS_date;       -- will return as nil if the date being tested is not |date=
    local error_message = "";
    local good_date = false;
    
    for k, v in pairs(date_parameters_list) do                                  -- for each date-holding parameter in the list
        if is_set(v) then                                                       -- if the parameter has a value
            if v:match("^c%. [1-9]%d%d%d?%a?$") then                            -- special case for c. year or with or without CITEREF disambiguator - only |date= and |year=
                local year = v:match("c%. ([1-9]%d%d%d?)%a?");                  -- get the year portion so it can be tested
                if 'date'==k then
                    anchor_year, COinS_date = v:match("((c%. [1-9]%d%d%d?)%a?)");   -- anchor year and COinS_date only from |date= parameter
                    good_date = is_valid_year(year);
                elseif 'year'==k then
                    good_date = is_valid_year(year);
                end
            elseif 'date'==k then                                               -- if the parameter is |date=
                if v:match("^n%.d%.%a?") then                                   -- if |date=n.d. with or without a CITEREF disambiguator
                    good_date, anchor_year, COinS_date = true, v:match("((n%.d%.)%a?)");    --"n.d."; no error when date parameter is set to no date
                elseif v:match("^nd%a?$") then                                  -- if |date=nd with or without a CITEREF disambiguator
                    good_date, anchor_year, COinS_date = true, v:match("((nd)%a?)");    --"nd"; no error when date parameter is set to no date
                else
                    good_date, anchor_year, COinS_date = check_date (v, tCOinS_date);   -- go test the date
                end
            elseif 'access-date'==k then                                        -- if the parameter is |date=
                good_date = check_date (v);                                     -- go test the date
                if true == good_date then                                       -- if the date is a valid date
                    good_date = is_valid_accessdate (v);                        -- is Wikipedia start date < accessdate < tomorrow's date?
                end
            else                                                                -- any other date-holding parameter
                good_date = check_date (v);                                     -- go test the date
            end
            if false==good_date then                                            -- assemble one error message so we don't add the tracking category multiple times
                if is_set(error_message) then                                   -- once we've added the first portion of the error message ...
                    error_message=error_message .. ", ";                        -- ... add a comma space separator
                end
                error_message=error_message .. "&#124;" .. k .. "=";            -- add the failed parameter
            end
        end
    end
    return anchor_year, error_message;                                          -- and done
end


--[[--------------------------< Y E A R _ D A T E _ C H E C K >------------------------------------------------

Compare the value provided in |year= with the year value(s) provided in |date=.  This function returns a numeric value:
    0 - year value does not match the year value in date
    1 - (default) year value matches the year value in date or one of the year values when date contains two years
    2 - year value matches the year value in date when date is in the form YYYY-MM-DD and year is disambiguated (|year=YYYYx)

]]

local function year_date_check (year_string, date_string)
    local year;
    local date1;
    local date2;
    local result = 1;                                                           -- result of the test; assume that the test passes
    
    year = year_string:match ('(%d%d%d%d?)');

    if date_string:match ('%d%d%d%d%-%d%d%-%d%d') and year_string:match ('%d%d%d%d%a') then --special case where date and year required YYYY-MM-DD and YYYYx
        date1 = date_string:match ('(%d%d%d%d)');
        year = year_string:match ('(%d%d%d%d)');
        if year ~= date1 then
            result = 0;                                                         -- years don't match
        else
            result = 2;                                                         -- years match; but because disambiguated, don't add to maint cat
        end
        
    elseif date_string:match ("%d%d%d%d?.-%d%d%d%d?") then                      -- any of the standard formats of date with two three- or four-digit years
        date1, date2 = date_string:match ("(%d%d%d%d?).-(%d%d%d%d?)");
        if year ~= date1 and year ~= date2 then
            result = 0;
        end

    elseif date_string:match ("%d%d%d%d[%s%-–]+%d%d") then                      -- YYYY-YY date ranges
        local century;
        date1, century, date2 = date_string:match ("((%d%d)%d%d)[%s%-–]+(%d%d)");
        date2 = century..date2;                                                 -- convert YY to YYYY
        if year ~= date1 and year ~= date2 then
            result = 0;
        end

    elseif date_string:match ("%d%d%d%d?") then                                 -- any of the standard formats of date with one year
        date1 = date_string:match ("(%d%d%d%d?)");
        if year ~= date1 then
            result = 0;
        end
    end
    return result;
end


local citation_config = {};

-- override <code>...</code> styling to remove color, border, and padding.  <code> css is specified here:
-- https://git.wikimedia.org/blob/mediawiki%2Fcore.git/69cd73811f7aadd093050dbf20ed70ef0b42a713/skins%2Fcommon%2FcommonElements.css#L199
local code_style="color:inherit; border:inherit; padding:inherit;";

--[[--------------------------< U N C A T E G O R I Z E D _ N A M E S P A C E S >------------------------------

List of namespaces that should not be included in citation error categories.  Same as setting notracking = true by default

Note: Namespace names should use underscores instead of spaces.

]]
local uncategorized_namespaces = { 'User', 'Talk', 'User_talk', 'Wikipedia_talk', 'File_talk', 'Template_talk',
    'Help_talk', 'Category_talk', 'Portal_talk', 'Book_talk', 'Draft', 'Draft_talk', 'Education_Program_talk', 
    'Module_talk', 'MediaWiki_talk' };

local uncategorized_subpages = {'/[Ss]andbox', '/[Tt]estcases'};        -- list of Lua patterns found in page names of pages we should not categorize

--[[--------------------------< M E S S A G E S >--------------------------------------------------------------

Translation table

The following contains fixed text that may be output as part of a citation.
This is separated from the main body to aid in future translations of this
module.

]]

local messages = {
    ['archived-dead'] = 'Archived from $1 on $2',
    ['archived-not-dead'] = '$1 from the original on $2',
    ['archived-missing'] = 'Archived from the original$1 on $2',
    ['archived'] = 'Archived',
    ['by'] = 'By',                                                              -- contributions to authored works: introduction, foreword, afterword
    ['cartography'] = 'Cartography by $1',
    ['editor'] = 'ed.',
    ['editors'] = 'eds.', 
    ['edition'] = '($1 ed.)', 
    ['episode'] = 'Episode $1',
    ['et al'] = 'et al.', 
    ['in'] = 'In',                                                              -- edited works
    ['inactive'] = 'inactive',
    ['inset'] = '$1 inset',
    ['lay summary'] = 'Lay summary',
    ['newsgroup'] = '[[Usenet newsgroup|Newsgroup]]:&nbsp;$1',
    ['original'] = 'the original',
    ['published'] = 'published $1',
    ['retrieved'] = 'Retrieved $1',
    ['season'] = 'Season $1', 
    ['section'] = '§ $1',
    ['sections'] = '§§ $1',
    ['series'] = 'Series $1',
    ['type'] = ' ($1)',                                                         -- for titletype
    ['written'] = 'Written at $1',

    ['vol'] = '$1 Vol.&nbsp;$2',                                                -- $1 is sepc; bold journal style volume is in presentation{}
    ['vol-no'] = '$1 Vol.&nbsp;$2 no.&nbsp;$3',                                 -- sepc, volume, issue
    ['issue'] = '$1 No.&nbsp;$2',                                               -- $1 is sepc

    ['j-vol'] = '$1 $2',                                                        -- sepc, volume; bold journal volume is in presentation{}
    ['j-issue'] = ' ($1)',

    ['nopp'] = '$1 $2';                                                         -- page(s) without prefix; $1 is sepc

    ['p-prefix'] = "$1 p.&nbsp;$2",                                             -- $1 is sepc
    ['pp-prefix'] = "$1 pp.&nbsp;$2",                                           -- $1 is sepc
    ['j-page(s)'] = ': $1',                                                     -- same for page and pages

    ['sheet'] = '$1 Sheet&nbsp;$2',                                             -- $1 is sepc
    ['sheets'] = '$1 Sheets&nbsp;$2',                                           -- $1 is sepc
    ['j-sheet'] = ': Sheet&nbsp;$1',
    ['j-sheets'] = ': Sheets&nbsp;$1',
    
    ['subscription'] = '<span style="font-size:90%; color:#555">(subscription required (<span title="Sources are not required to be available online. Online sources do not have to be freely available. The site may require a paid subscription." style="border-bottom:1px dotted;cursor:help">help</span>))</span>' ..
        '[[Category:Pages containing links to subscription-only content]]', 
    
    ['registration']='<span style="font-size:90%; color:#555">(registration required (<span title="Sources are not required to be available online. Online sources do not have to be freely available. The site may require registration." style="border-bottom:1px dotted;cursor:help">help</span>))</span>' ..
        '[[Category:Pages with login required references or sources]]',
    
    ['language'] = '(in $1)', 
    ['via'] = " &ndash; via $1",
    ['event'] = 'Event occurs at',
    ['minutes'] = 'minutes in', 
    
    ['parameter-separator'] = ', ',
    ['parameter-final-separator'] = ', and ',
    ['parameter-pair-separator'] = ' and ',
    
    -- Determines the location of the help page
    ['help page link'] = 'Help:CS1 errors',
    ['help page label'] = 'help',
    
    -- Internal errors (should only occur if configuration is bad)
    ['undefined_error'] = 'Called with an undefined error condition',
    ['unknown_manual_ID'] = 'Unrecognized manual ID mode',
    ['unknown_ID_mode'] = 'Unrecognized ID mode',
    ['unknown_argument_map'] = 'Argument map not defined for this variable',
    ['bare_url_no_origin'] = 'Bare url found but origin indicator is nil or empty',
}

--[[--------------------------< P R E S E N T A T I O N >------------------------------------------------------

Fixed presentation markup.  Originally part of citation_config.messages it has been moved into its own, more semantically
correct place.

]]
local presentation = 
    {
    -- Error output
    -- .error class is specified at https://git.wikimedia.org/blob/mediawiki%2Fcore.git/9553bd02a5595da05c184f7521721fb1b79b3935/skins%2Fcommon%2Fshared.css#L538
    -- .citation-comment class is specified at Help:CS1_errors#Controlling_error_message_display
    ['hidden-error'] = '<span style="display:none;font-size:100%" class="error citation-comment">$1</span>',
    ['visible-error'] = '<span style="font-size:100%" class="error citation-comment">$1</span>',

    ['accessdate'] = '<span class="reference-accessdate">$1$2</span>',          -- to allow editors to hide accessdate using personal css

    ['bdi'] = '<bdi$1>$2</bdi>',                                                -- bidirectional isolation used with |script-title= and the like

    ['format'] = ' <span style="font-size:85%;">($1)</span>',                   -- for |format=, |chapter-format=, etc

    ['italic-title'] = "''$1''",

    ['kern-left'] = '<span style="padding-left:0.2em;">$1</span>$2',            -- spacing to use when title contains leading single or double quote mark
    ['kern-right'] = '$1<span style="padding-right:0.2em;">$2</span>',          -- spacing to use when title contains trailing single or double quote mark

    ['nowrap1'] = '<span class="nowrap">$1</span>',                             -- for nowrapping an item: <span ...>yyyy-mm-dd</span>
    ['nowrap2'] = '<span class="nowrap">$1</span> $2',                          -- for nowrapping portions of an item: <span ...>dd mmmm</span> yyyy (note white space)
    
    ['parameter'] = '<code style="'..code_style..'">&#124;$1=</code>',

    ['quoted-text'] = '<q>$1</q>',                                              -- for wrapping |quote= content
    ['quoted-title'] = '"$1"',

    ['trans-italic-title'] = "&#91;''$1''&#93;",
    ['trans-quoted-title'] = "&#91;$1&#93;",
    ['vol-bold'] = ' <b>$1</b>',                                                    -- for journal cites; for other cites ['vol'] in messages{}
    }

--[[--------------------------< A L I A S E S >----------------------------------------------------------------

Aliases table for commonly passed parameters

]]

local aliases = {
    ['AccessDate'] = {'access-date', 'accessdate'},
    ['Agency'] = 'agency',
    ['AirDate'] = {'air-date', 'airdate'},
    ['ArchiveDate'] = {'archive-date', 'archivedate'},
    ['ArchiveFormat'] = 'archive-format',
    ['ArchiveURL'] = {'archive-url', 'archiveurl'},
    ['ASINTLD'] = {'ASIN-TLD', 'asin-tld'},
    ['At'] = 'at',
    ['Authors'] = {'authors', 'people', 'host', 'credits'},
    ['BookTitle'] = {'book-title', 'booktitle'},
    ['Callsign'] = {'call-sign', 'callsign'},                                   -- cite interview
    ['Cartography'] = 'cartography',
    ['Chapter'] = {'chapter', 'contribution', 'entry', 'article', 'section'},
    ['ChapterFormat'] = {'chapter-format', 'contribution-format', 'section-format'};
    ['ChapterURL'] = {'chapter-url', 'chapterurl', 'contribution-url', 'contributionurl', 'section-url', 'sectionurl'},
    ['City'] = 'city',                                                          -- cite interview
    ['Class'] = 'class',                                                        -- cite arxiv and arxiv identifiers
    ['Coauthors'] = {'coauthors', 'coauthor'},                                  -- coauthor and coauthors are deprecated; remove after 1 January 2015?
    ['Conference'] = {'conference', 'event'},
    ['ConferenceFormat'] = {'conference-format', 'event-format'},
    ['ConferenceURL'] = {'conference-url', 'conferenceurl', 'event-url', 'eventurl'},
    ['Contribution'] = 'contribution',                                          -- introduction, foreword, afterword, etc; required when |contributor= set
    ['Date'] = {'date', 'air-date', 'airdate'},
    ['DeadURL'] = {'dead-url', 'deadurl'},
    ['Degree'] = 'degree',
    ['DisplayAuthors'] = {'display-authors', 'displayauthors'},
    ['DisplayEditors'] = {'display-editors', 'displayeditors'},
    ['Docket'] = 'docket',
    ['DoiBroken'] = {'doi-broken', 'doi-broken-date', 'doi-inactive-date', 'doi_brokendate', 'doi_inactivedate'},
    ['Edition'] = 'edition',
    ['Editors'] = 'editors',
    ['Embargo'] = 'embargo',
    ['Encyclopedia'] = {'encyclopedia', 'encyclopaedia'},                       -- this one only used by citation
    ['Episode'] = 'episode',                                                    -- cite serial only TODO: make available to cite episode?
    ['Format'] = 'format',
    ['ID'] = {'id', 'ID'},
    ['IgnoreISBN'] = {'ignore-isbn-error', 'ignoreisbnerror'},
    ['Inset'] = 'inset',
    ['Issue'] = {'issue', 'number'},
    ['Language'] = {'language', 'in'},
    ['LastAuthorAmp'] = {'last-author-amp', 'lastauthoramp'},
    ['LayDate'] = {'lay-date', 'laydate'},
    ['LayFormat'] = 'lay-format',
    ['LaySource'] = {'lay-source', 'laysource'},
    ['LayURL'] = {'lay-url', 'lay-summary', 'layurl', 'laysummary'},
    ['MailingList'] = {'mailinglist', 'mailing-list'},                          -- cite mailing list only
    ['Map'] = 'map',                                                            -- cite map only
    ['MapFormat'] = 'map-format',                                               -- cite map only
    ['MapURL'] = {'mapurl', 'map-url'},                                         -- cite map only
    ['MessageID'] = 'message-id',
    ['Minutes'] = 'minutes',
    ['Mode'] = 'mode',
    ['NameListFormat'] = 'name-list-format',
    ['Network'] = 'network',
    ['NoPP'] = {'no-pp', 'nopp'},
    ['NoTracking'] = {'template-doc-demo', 'template doc demo', 'no-cat', 'nocat', 
        'no-tracking', 'notracking'},
    ['Number'] = 'number',                                                      -- this case only for cite techreport
    ['OrigYear'] = {'orig-year', 'origyear'},
    ['Others'] = {'others', 'interviewer', 'interviewers'},
    ['Page'] = {'p', 'page'},
    ['Pages'] = {'pp', 'pages'},
    ['Periodical'] = {'journal', 'newspaper', 'magazine', 'work',
        'website',  'periodical', 'encyclopedia', 'encyclopaedia', 'dictionary', 'mailinglist'},
    ['Place'] = {'place', 'location'},
    ['Program'] = 'program',                                                    -- cite interview
    ['PostScript'] = 'postscript',
    ['PublicationDate'] = {'publicationdate', 'publication-date'},
    ['PublicationPlace'] = {'publication-place', 'publicationplace'},
    ['PublisherName'] = {'publisher', 'distributor', 'institution', 'newsgroup'},
    ['Quote'] = {'quote', 'quotation'},
    ['Ref'] = 'ref',
    ['RegistrationRequired'] = 'registration',
    ['Scale'] = 'scale',
    ['ScriptChapter'] = 'script-chapter',
    ['ScriptTitle'] = 'script-title',
    ['Section'] = 'section',
    ['Season'] = 'season',
    ['Sections'] = 'sections',                                                  -- cite map only
    ['Series'] = {'series', 'version'},
    ['SeriesSeparator'] = 'series-separator',
    ['SeriesLink'] = {'series-link', 'serieslink'},
    ['SeriesNumber'] = {'series-number', 'series-no', 'seriesnumber', 'seriesno'},
    ['Sheet'] = 'sheet',                                                        -- cite map only
    ['Sheets'] = 'sheets',                                                      -- cite map only
    ['Station'] = 'station',
    ['SubscriptionRequired'] = 'subscription',
    ['Time'] = 'time',
    ['TimeCaption'] = {'time-caption', 'timecaption'},
    ['Title'] = 'title',
    ['TitleLink'] = {'title-link', 'episode-link', 'titlelink', 'episodelink'},
    ['TitleNote'] = 'department',
    ['TitleType'] = {'type', 'medium'},
    ['TransChapter'] = {'trans-chapter', 'trans_chapter'},
    ['TransMap'] = 'trans-map',                                                 -- cite map only
    ['Transcript'] = 'transcript',
    ['TranscriptFormat'] = 'transcript-format',
    ['TranscriptURL'] = {'transcript-url', 'transcripturl'},
    ['TransTitle'] = {'trans-title', 'trans_title'},
    ['URL'] = {'url', 'URL'},
    ['Vauthors'] = 'vauthors',
    ['Veditors'] = 'veditors',
    ['Via'] = 'via',
    ['Volume'] = 'volume',
    ['Year'] = 'year',

    ['AuthorList-First'] = {"first#", "given#", "author-first#", "author#-first"},
    ['AuthorList-Last'] = {"last#", "author#", "surname#", "author-last#", "author#-last", "subject#"},
    ['AuthorList-Link'] = {"authorlink#", "author-link#", "author#-link", "subjectlink#", "author#link", "subject-link#", "subject#-link", "subject#link"},
    ['AuthorList-Mask'] = {"author-mask#", "authormask#", "author#mask", "author#-mask"},
    
    ['ContributorList-First'] = {'contributor-first#','contributor#-first'},
    ['ContributorList-Last'] = {'contributor#', 'contributor-last#', 'contributor#-last'},
    ['ContributorList-Link'] = {'contributor-link#', 'contributor#-link'},
    ['ContributorList-Mask'] = {'contributor-mask#', 'contributor#-mask'},

    ['EditorList-First'] = {"editor-first#", "editor#-first", "editor-given#", "editor#-given"},
    ['EditorList-Last'] = {"editor#", "editor-last#", "editor#-last", "editor-surname#", "editor#-surname"},
    ['EditorList-Link'] = {"editor-link#", "editor#-link", "editorlink#", "editor#link"},
    ['EditorList-Mask'] = {"editor-mask#", "editor#-mask", "editormask#", "editor#mask"},
    
    ['TranslatorList-First'] = {'translator-first#','translator#-first'},
    ['TranslatorList-Last'] = {'translator#', 'translator-last#', 'translator#-last'},
    ['TranslatorList-Link'] = {'translator-link#', 'translator#-link'},
    ['TranslatorList-Mask'] = {'translator-mask#', 'translator#-mask'},
}

--[[--------------------------< D E F A U L T S >--------------------------------------------------------------

Default parameter values

TODO: keep this?  Only one default?
]]

local defaults = {
    ['DeadURL'] = 'yes',
}


--[[--------------------------< V O L U M E ,  I S S U E ,  P A G E S >----------------------------------------

These tables hold cite class values (from the template invocation) and identify those templates that support
|volume=, |issue=, and |page(s)= parameters.  Cite conference and cite map require further qualification which
is handled in the main module.

]]

local templates_using_volume = {'citation', 'audio-visual', 'book', 'conference', 'encyclopaedia', 'interview', 'journal', 'magazine', 'map', 'news', 'report', 'techreport'}
local templates_using_issue = {'citation', 'conference', 'episode', 'interview', 'journal', 'magazine', 'map', 'news', 'gazette'}
local templates_not_using_page = {'audio-visual', 'episode', 'mailinglist', 'newsgroup', 'podcast', 'serial', 'sign', 'speech'}
local templates_using_accessdate = {'nrisref', 'gnis', 'policy', 'season', 'sports-reference', 'nhle', 'england'}
local templates_using_series_no_as_id = {'nrisref', 'gnis', 'geonet3', 'season', 'nhle', 'england'}



--[[--------------------------< K E Y W O R D S >--------------------------------------------------------------

This table holds keywords for those parameters that have defined sets of acceptible keywords.

]]

local keywords = {
    ['yes_true_y'] = {'yes', 'true', 'y'},                                      -- ignore-isbn-error, last-author-amp, no-tracking, nopp, registration, subscription
    ['deadurl'] = {'yes', 'true', 'y', 'no', 'unfit', 'usurped'},
    ['mode'] = {'cs1', 'cs2'},
    ['name-list-format'] = {'vanc'},
    ['contribution'] = {'afterword', 'foreword', 'introduction', 'preface'},    -- generic contribution titles that are rendered unquoted in the 'chapter' position
}


--[[--------------------------< I N V I S I B L E _ C H A R A C T E R S >--------------------------------------

This table holds non-printing or invisible characters indexed either by name or by Unicode group. Values are decimal
representations of UTF-8 codes.  The table is organized as a table of tables because the lua pairs keyword returns
table data in an arbitrary order.  Here, we want to process the table from top to bottom because the entries at
the top of the table are also found in the ranges specified by the entries at the bottom of the table.

This list contains patterns for templates like {{'}} which isn't an error but transcludes characters that are
invisible.  These kinds of patterns must be recognized by the functions that use this list.

Also here is a pattern that recognizes stripmarkers that begin and end with the delete characters.  The nowiki
stripmarker is not an error but some others are because the parameter values that include them become part of the
template's metadata before stripmarker replacement.

]]

local invisible_chars = {
    {'replacement', '\239\191\189'},                                            -- U+FFFD, EF BF BD
    {'apostrophe', '&zwj;\226\128\138\039\226\128\139'},                        -- apostrophe template: &zwj; hair space ' zero-width space; not an error
    {'apostrophe', '\226\128\138\039\226\128\139'},                             -- apostrophe template: hair space ' zero-width space; (as of 2015-12-11) not an error
    {'zero width joiner', '\226\128\141'},                                      -- U+200D, E2 80 8D
    {'zero width space', '\226\128\139'},                                       -- U+200B, E2 80 8B
    {'hair space', '\226\128\138'},                                             -- U+200A, E2 80 8A
    {'soft hyphen', '\194\173'},                                                -- U+00AD, C2 AD
    {'horizontal tab', '\009'},                                                 -- U+0009 (HT), 09
    {'line feed', '\010'},                                                      -- U+0010 (LF), 0A
    {'carriage return', '\013'},                                                -- U+0013 (CR), 0D
--  {'nowiki stripmarker', '\127UNIQ%-%-nowiki%-[%a%d]+%-QINU\127'},            -- nowiki stripmarker; not an error
    {'stripmarker', '\127UNIQ%-%-(%a+)%-[%a%d]+%-QINU\127'},                    -- stripmarker; may or may not be an error; capture returns the stripmaker type
    {'delete', '\127'},                                                         -- U+007F (DEL), 7F; must be done after stripmarker test
    {'C0 control', '[\000-\008\011\012\014-\031]'},                             -- U+0000–U+001F (NULL–US), 00–1F (except HT, LF, CR (09, 0A, 0D))
    {'C1 control', '[\194\128-\194\159]'},                                      -- U+0080–U+009F (XXX–APC), C2 80 – C2 9F
    {'Specials', '[\239\191\185-\239\191\191]'},                                -- U+FFF9-U+FFFF, EF BF B9 – EF BF BF
    {'Private use area', '[\238\128\128-\239\163\191]'},                        -- U+E000–U+F8FF, EE 80 80 – EF A3 BF
    {'Supplementary Private Use Area-A', '[\243\176\128\128-\243\191\191\189]'},    -- U+F0000–U+FFFFD, F3 B0 80 80 – F3 BF BF BD
    {'Supplementary Private Use Area-B', '[\244\128\128\128-\244\143\191\189]'},    -- U+100000–U+10FFFD, F4 80 80 80 – F4 8F BF BD
}


--[[--------------------------< M A I N T E N A N C E _ C A T E G O R I E S >----------------------------------

Here we name maintenance categories to be used in maintenance messages.

]]

local maint_cats = {
    ['ASIN'] = 'CS1 maint: ASIN uses ISBN',
    ['date_year'] = 'CS1 maint: Date and year',
    ['disp_auth_ed'] = 'CS1 maint: display-$1',                                 -- $1 is authors or editors
    ['embargo'] = 'CS1 maint: PMC embargo expired',
    ['english'] = 'CS1 maint: English language specified',
    ['etal'] = 'CS1 maint: Explicit use of et al.',
    ['extra_text'] = 'CS1 maint: Extra text',
    ['unknown_lang'] = 'CS1 maint: Unrecognized language',
    ['untitled'] = 'CS1 maint: Untitled periodical',
    }

--[[--------------------------< P R O P E R T I E S _ C A T E G O R I E S >------------------------------------

Here we name properties categories

]]

local prop_cats = {
    ['foreign_lang_source'] = 'CS1 $1-language sources ($2)',                   -- |language= categories; $1 is language name, $2 is ISO639-1 code
    ['script'] = 'CS1 uses foreign language script',                            -- when language specified by |script-title=xx: doesn't have its own category
    ['script_with_name'] = 'CS1 uses $1-language script ($2)',                  -- |script-title=xx: has matching category; $1 is language name, $2 is ISO639-1 code
    }



--[[--------------------------< T I T L E _ T Y P E S >--------------------------------------------------------

Here we map a template's CitationClass to TitleType (default values for |type= parameter)

]]

local title_types = {
    ['AV-media-notes'] = 'Media notes',
    ['DVD-notes'] = 'Media notes',
    ['mailinglist'] = 'Mailing list',
    ['map'] = 'Map',
    ['podcast'] = 'Podcast',
    ['pressrelease'] = 'Press release',
    ['report'] = 'Report',
    ['techreport'] = 'Technical report',
    ['thesis'] = 'Thesis',
    }

--[[--------------------------< E R R O R _ C O N D I T I O N S >----------------------------------------------

Error condition table

The following contains a list of IDs for various error conditions defined in the code.  For each ID, we specify a
text message to display, an error category to include, and whether the error message should be wrapped as a hidden comment.

Anchor changes require identical changes to matching anchor in Help:CS1 errors

]]

local error_conditions = {
    accessdate_missing_url = {
        message = '<code style="'..code_style..'">&#124;access-date=</code> requires <code style="'..code_style..'">&#124;url=</code>',
        anchor = 'accessdate_missing_url',
        category = 'Pages using citations with accessdate and no URL',
        hidden = true },
    archive_missing_date = {
        message = '<code style="'..code_style..'">&#124;archive-url=</code> requires <code style="'..code_style..'">&#124;archive-date=</code>',
        anchor = 'archive_missing_date',
        category = 'Pages with archiveurl citation errors',
        hidden = false },
    archive_missing_url = {
        message = '<code style="'..code_style..'">&#124;archive-url=</code> requires <code style="'..code_style..'">&#124;url=</code>',
        anchor = 'archive_missing_url',
        category = 'Pages with archiveurl citation errors',
        hidden = false },
    arxiv_missing = {
        message = '<code style="'..code_style..'">&#124;arxiv=</code> required',
        anchor = 'arxiv_missing',
        category = 'CS1 errors: arXiv',                                         -- same as bad arxiv
        hidden = false },
    arxiv_params_not_supported = {
        message = 'Unsupported parameter(s) in cite arXiv',
        anchor = 'arxiv_params_not_supported',
        category = 'CS1 errors: arXiv',                                         -- same as bad arxiv
        hidden = false },
    bad_arxiv = {
        message = 'Check <code style="'..code_style..'">&#124;arxiv=</code> value',
        anchor = 'bad_arxiv',
        category = 'CS1 errors: arXiv',
        hidden = false },
    bad_asin = {
        message = 'Check <code style="'..code_style..'">&#124;asin=</code> value',
        anchor = 'bad_asin',
        category ='CS1 errors: ASIN',
        hidden = false },
    bad_date = {
        message = 'Check date values in: <code style="'..code_style..'">$1</code>',
        anchor = 'bad_date',
        category = 'CS1 errors: dates',
        hidden = false },
    bad_doi = {
        message = 'Check <code style="'..code_style..'">&#124;doi=</code> value',
        anchor = 'bad_doi',
        category = 'CS1 errors: DOI',
        hidden = false },
    bad_isbn = {
        message = 'Check <code style="'..code_style..'">&#124;isbn=</code> value',
        anchor = 'bad_isbn',
        category = 'CS1 errors: ISBN',
        hidden = false },
    bad_ismn = {
        message = 'Check <code style="'..code_style..'">&#124;ismn=</code> value',
        anchor = 'bad_ismn',
        category = 'CS1 errors: ISMN',
        hidden = false },
    bad_issn = {
        message = 'Check <code style="'..code_style..'">&#124;issn=</code> value',
        anchor = 'bad_issn',
        category = 'CS1 errors: ISSN',
        hidden = false },
    bad_lccn = {
        message = 'Check <code style="'..code_style..'">&#124;lccn=</code> value',
        anchor = 'bad_lccn',
        category = 'CS1 errors: LCCN',
        hidden = false },
    bad_message_id = {
        message = 'Check <code style="'..code_style..'">&#124;message-id=</code> value',
        anchor = 'bad_message_id',
        category = 'CS1 errors: message-id',
        hidden = false },
    bad_ol = {
        message = 'Check <code style="'..code_style..'">&#124;ol=</code> value',
        anchor = 'bad_ol',
        category = 'CS1 errors: OL',
        hidden = false },
    bad_paramlink = {                                                           -- for |title-link=, |author/editor/translator-link=, |series-link=, |episode-link=
        message = 'Check <code style="'..code_style..'">&#124;$1=</code> value',
        anchor = 'bad_paramlink',
        category = 'CS1 errors: parameter link',
        hidden = false },
    bad_pmc = {
        message = 'Check <code style="'..code_style..'">&#124;pmc=</code> value',
        anchor = 'bad_pmc',
        category = 'CS1 errors: PMC',
        hidden = false },
    bad_pmid = {
        message = 'Check <code style="'..code_style..'">&#124;pmid=</code> value',
        anchor = 'bad_pmid',
        category = 'CS1 errors: PMID',
        hidden = false },
    bad_url = {
        message = 'Check <code style="'..code_style..'">$1</code> value',
        anchor = 'bad_url',
        category = 'Pages with URL errors',
        hidden = false },
    bare_url_missing_title = {
        message = '$1 missing title',
        anchor = 'bare_url_missing_title',
        category = 'Pages with citations having bare URLs',
        hidden = false },
    chapter_ignored = {
        message = '<code style="'..code_style..'">&#124;$1=</code> ignored',
        anchor = 'chapter_ignored',
        category = 'CS1 errors: chapter ignored',
        hidden = false },
    citation_missing_title = {
        message = 'Missing or empty <code style="'..code_style..'">&#124;$1=</code>',
        anchor = 'citation_missing_title',
        category = 'Pages with citations lacking titles',
        hidden = false },
    cite_web_url = {                                                            -- this error applies to cite web and to cite podcast
        message = 'Missing or empty <code style="'..code_style..'">&#124;url=</code>',
        anchor = 'cite_web_url',
        category = 'Pages using web citations with no URL',
        hidden = true },
    coauthors_missing_author = {
        message = '<code style="'..code_style..'">&#124;coauthors=</code> requires <code style="'..code_style..'">&#124;author=</code>',
        anchor = 'coauthors_missing_author',
        category = 'CS1 errors: coauthors without author',
        hidden = false },
    contributor_ignored = {
        message = '<code style="'..code_style..'">&#124;contributor=</code> ignored</code>',
        anchor = 'contributor_ignored',
        category = 'CS1 errors: contributor',
        hidden = false },
    contributor_missing_required_param = {
        message = '<code style="'..code_style..'">&#124;contributor=</code> requires <code style="'..code_style..'">&#124;$1=</code>',
        anchor = 'contributor_missing_required_param',
        category = 'CS1 errors: contributor',
        hidden = false },
    deprecated_params = {
        message = 'Cite uses deprecated parameter <code style="'..code_style..'">&#124;$1=</code>',
        anchor = 'deprecated_params',
        category = 'Pages containing cite templates with deprecated parameters',
        hidden = false },
    empty_citation = {
        message = 'Empty citation',
        anchor = 'empty_citation',
        category = 'Pages with empty citations',
        hidden = false },
    first_missing_last = {
        message = '<code style="'..code_style..'">&#124;first$2=</code> missing <code style="'..code_style..'">&#124;last$2=</code> in $1',
        anchor = 'first_missing_last',
        category = 'CS1 errors: missing author or editor',
        hidden = false },
    format_missing_url = {
        message = '<code style="'..code_style..'">&#124;$1=</code> requires <code style="'..code_style..'">&#124;$2=</code>',
        anchor = 'format_missing_url',
        category = 'Pages using citations with format and no URL',
        hidden = true },
    implict_etal_editor = {
        message = '<code style="'..code_style..'">&#124;display-editors=</code> suggested',
        anchor = 'displayeditors',
        category = 'Pages using citations with old-style implicit et al. in editors',
        hidden = true },
    invalid_param_val = {
        message = 'Invalid <code style="'..code_style..'">&#124;$1=$2</code>',
        anchor = 'invalid_param_val',
        category = 'CS1 errors: invalid parameter value',
        hidden = false },
    invisible_char = {
        message = '$1 in $2 at position $3',
        anchor = 'invisible_char',
        category = 'CS1 errors: invisible characters',
        hidden = false },
    missing_name = {
        message = 'Missing <code style="'..code_style..'">&#124;last$2=</code> in $1',
        anchor = 'missing_name',
        category = 'CS1 errors: missing author or editor',
        hidden = false },
    param_has_ext_link = {
        message = 'External link in <code style="'..code_style..'">$1</code>',
        anchor = 'param_has_ext_link',
        category = 'CS1 errors: external links',
        hidden = false },
    parameter_ignored = {
        message = 'Unknown parameter <code style="'..code_style..'">&#124;$1=</code> ignored',
        anchor = 'parameter_ignored',
        category = 'Pages with citations using unsupported parameters',
        hidden = false },
    parameter_ignored_suggest = {
        message = 'Unknown parameter <code style="'..code_style..'">&#124;$1=</code> ignored (<code style="'..code_style..'">&#124;$2=</code> suggested)',
        anchor = 'parameter_ignored_suggest',
        category = 'Pages with citations using unsupported parameters',
        hidden = false },
    redundant_parameters = {
        message = 'More than one of $1 specified',
        anchor = 'redundant_parameters',
        category = 'Pages with citations having redundant parameters',
        hidden = false },
    text_ignored = {
        message = 'Text "$1" ignored',
        anchor = 'text_ignored',
        category = 'Pages with citations using unnamed parameters',
        hidden = false },
    trans_missing_title = {
        message = '<code style="'..code_style..'">&#124;trans-$1=</code> requires <code style="'..code_style..'">&#124;$1=</code>',
        anchor = 'trans_missing_title',
        category = 'CS1 errors: translated title',
        hidden = false },
    vancouver = {
        message = 'Vancouver style error',
        anchor = 'vancouver',
        category = 'CS1 errors: Vancouver style',
        hidden = false },
    wikilink_in_url = {
        message = 'URL–wikilink conflict',                                      -- uses ndash
        anchor = 'wikilink_in_url',
        category = 'CS1 errors: URL–wikilink conflict',                         -- uses ndash
        hidden = false },
}

--[[--------------------------< I D _ H A N D L E R S >--------------------------------------------------------

The following contains a list of values for various defined identifiers.  For each identifier we specify a
variety of information necessary to properly render the identifier in the citation.

    parameters: a list of parameter aliases for this identifier
    link: Wikipedia article name
    label: the alternate name to apply to link
    mode:   'manual' when there is a specific function in the code to handle the identifier;
            'external' for identifiers that link outside of Wikipedia;
    prefix: the first part of a url that will be concatenated with a second part which usually contains the identifier
    encode: true if uri should be percent encoded; otherwise false
    COinS: identifier link or keyword for use in COinS:
        for identifiers registered at info-uri.info use: info:....
        for identifiers that have COinS keywords, use the keyword: rft.isbn, rft.issn, rft.eissn
        for others make a url using the value in prefix, use the keyword: pre (not checked; any text other than 'info' or 'rft' works here)
        set to nil to leave the identifier out of the COinS
    separator: character or text between label and the identifier in the rendered citation
]]

local id_handlers = {
    ['ARXIV'] = {
        parameters = {'arxiv', 'ARXIV', 'eprint'}, 
        link = 'arXiv',
        label = 'arXiv',
        mode = 'manual',
        prefix = '//arxiv.org/abs/',                                            -- protocol relative tested 2013-09-04
        encode = false,
        COinS = 'info:arxiv',
        separator = ':',
    },
    ['ASIN'] = {
        parameters = { 'asin', 'ASIN' },       
        link = 'Amazon Standard Identification Number',
        label = 'ASIN',
        mode = 'manual',
        prefix = '//www.amazon.',
        COinS = nil,                                                            -- no COinS for this id (needs thinking on implementation because |asin-tld=)
        separator = '&nbsp;',
        encode = false;
    },
    ['BIBCODE'] = {
        parameters = {'bibcode', 'BIBCODE'}, 
        link = 'Bibcode',
        label = 'Bibcode',
        mode = 'external',
        prefix = 'http://adsabs.harvard.edu/abs/',
        encode = false,
        COinS = 'info:bibcode',
        separator = ':',
    },
    ['DOI'] = {
        parameters = { 'doi', 'DOI' },
        link = 'Digital object identifier',
        label = 'doi',
        mode = 'manual',
        prefix = '//dx.doi.org/',
        COinS = 'info:doi',
        separator = ':',
        encode = true,
    },
    ['ISBN'] = {
        parameters = {'isbn', 'ISBN', 'isbn13', 'ISBN13'}, 
        link = 'International Standard Book Number',
        label = 'ISBN',
        mode = 'manual',
        prefix = 'Special:BookSources/',
        COinS = 'rft.isbn',
        separator = '&nbsp;',
    },
    ['ISMN'] = {
        parameters = {'ismn', 'ISMN'}, 
        link = 'International Standard Music Number',
        label = 'ISMN',
        mode = 'manual',
        prefix = '',                                                            -- not currently used; 
        COinS = 'nil',                                                          -- nil because we can't use pre or rft or info:
        separator = '&nbsp;',
    },
    ['ISSN'] = {
        parameters = {'issn', 'ISSN'}, 
        link = 'International Standard Serial Number',
        label = 'ISSN',
        mode = 'manual',
        prefix = '//www.worldcat.org/issn/',
        COinS = 'rft.issn',
        encode = false,
        separator = '&nbsp;',
    },
    ['JFM'] = {
        parameters = {'jfm', 'JFM'}, 
        link = 'Jahrbuch über die Fortschritte der Mathematik',
        label = 'JFM',
        mode = 'external',
        prefix = '//zbmath.org/?format=complete&q=an:',
        COinS = 'pre',                                                          -- use prefix value
        encode = true,
        separator = '&nbsp;',
    },
    ['JSTOR'] = {
        parameters = {'jstor', 'JSTOR'}, 
        link = 'JSTOR',
        label = 'JSTOR',
        mode = 'external',
        prefix = '//www.jstor.org/stable/',                                     -- protocol relative tested 2013-09-04
        COinS = 'pre',                                                          -- use prefix value
        encode = false,
        separator = '&nbsp;',
    },
    ['LCCN'] = {
        parameters = {'LCCN', 'lccn'}, 
        link = 'Library of Congress Control Number',
        label = 'LCCN',
        mode = 'manual',
        prefix = 'http://lccn.loc.gov/',
        COinS = 'info:lccn',                                                    -- use prefix value
        encode = false,
        separator = '&nbsp;',
    },
    ['MR'] = {
        parameters = {'MR', 'mr'}, 
        link = 'Mathematical Reviews',
        label = 'MR',
        mode = 'external',
        prefix = '//www.ams.org/mathscinet-getitem?mr=',                        -- protocol relative tested 2013-09-04
        COinS = 'pre',                                                          -- use prefix value
        encode = true,
        separator = '&nbsp;',
    },
    ['OCLC'] = {
        parameters = {'OCLC', 'oclc'}, 
        link = 'OCLC',
        label = 'OCLC',
        mode = 'external',
        prefix = '//www.worldcat.org/oclc/',
        COinS = 'info:oclcnum',
        encode = true,
        separator = '&nbsp;',
    },
    ['OL'] = {
        parameters = { 'ol', 'OL' },
        link = 'Open Library',
        label = 'OL',
        mode = 'manual',
        prefix = '//openlibrary.org/',
        COinS = nil,                                                            -- no COinS for this id (needs thinking on implementation because /authors/books/works/OL)
        separator = '&nbsp;',
        endode = true,
    },
    ['OSTI'] = {
        parameters = {'OSTI', 'osti'}, 
        link = 'Office of Scientific and Technical Information',
        label = 'OSTI',
        mode = 'external',
        prefix = '//www.osti.gov/energycitations/product.biblio.jsp?osti_id=',  -- protocol relative tested 2013-09-04
        COinS = 'pre',                                                          -- use prefix value
        encode = true,
        separator = '&nbsp;',
    },
    ['PMC'] = {
        parameters = {'PMC', 'pmc'}, 
        link = 'PubMed Central',
        label = 'PMC',
        mode = 'manual',
        prefix = '//www.ncbi.nlm.nih.gov/pmc/articles/PMC', 
        suffix = " ",
        COinS = 'pre',                                                          -- use prefix value
        encode = true,
        separator = '&nbsp;',
    },
    ['PMID'] = {
        parameters = {'PMID', 'pmid'}, 
        link = 'PubMed Identifier',
        label = 'PMID',
        mode = 'manual',
        prefix = '//www.ncbi.nlm.nih.gov/pubmed/',
        COinS = 'info:pmid',
        encode = false,
        separator = '&nbsp;',
    },
    ['RFC'] = {
        parameters = {'RFC', 'rfc'}, 
        link = 'Request for Comments',
        label = 'RFC',
        mode = 'external',
        prefix = '//tools.ietf.org/html/rfc',
        COinS = 'pre',                                                          -- use prefix value
        encode = false,
        separator = '&nbsp;',
    },
    ['SSRN'] = {
        parameters = {'SSRN', 'ssrn'}, 
        link = 'Social Science Research Network',
        label = 'SSRN',
        mode = 'external',
        prefix = '//ssrn.com/abstract=',                                        -- protocol relative tested 2013-09-04
        COinS = 'pre',                                                          -- use prefix value
        encode = true,
        separator = '&nbsp;',
    },
    ['USENETID'] = {
        parameters = {'message-id'},
        link = 'Usenet',
        label = 'Usenet:',
        mode = 'manual',
        prefix = 'news:',
        encode = false,
        COinS = 'pre',                                                          -- use prefix value
        separator = '&nbsp;',
    },
    ['ZBL'] = {
        parameters = {'ZBL', 'zbl'}, 
        link = 'Zentralblatt MATH',
        label = 'Zbl',
        mode = 'external',
        prefix = '//zbmath.org/?format=complete&q=an:',
        COinS = 'pre',                                                          -- use prefix value
        encode = true,
        separator = '&nbsp;',
    },
}

local cfg =  {
    aliases = aliases,
    defaults = defaults,
    error_conditions = error_conditions,
    id_handlers = id_handlers,
    keywords = keywords,
    invisible_chars = invisible_chars,
    maint_cats = maint_cats,
    messages = messages,
    presentation = presentation,
    prop_cats = prop_cats,
    title_types = title_types,
    uncategorized_namespaces = uncategorized_namespaces,
    uncategorized_subpages = uncategorized_subpages,
    templates_using_volume = templates_using_volume,
    templates_using_issue = templates_using_issue,
    templates_not_using_page = templates_not_using_page,
    }


local basic_arguments = {
    ['accessdate'] = true,
    ['access-date'] = true,
    ['agency'] = true,
    ['airdate'] = true,
    ['air-date'] = true,
    ['archivedate'] = true,
    ['archive-date'] = true,
    ['archive-format'] = true,
    ['archiveurl'] = true,
    ['archive-url'] = true,
    ['article'] = true,
    ['arxiv'] = true,
    ['ARXIV'] = true,
    ['asin'] = true,
    ['ASIN'] = true,
    ['asin-tld'] = true,
    ['ASIN-TLD'] = true,
    ['at'] = true,
    ['author'] = true,
    ['author-first'] = true,
    ['author-last'] = true,
    ['authorlink'] = true,
    ['author-link'] = true,
    ['authormask'] = true,
    ['author-mask'] = true,
    ['authors'] = true,
    ['bibcode'] = true,
    ['BIBCODE'] = true,
    ['booktitle'] = true,
    ['book-title'] = true,
    ['callsign'] = true,            -- cite interview
    ['call-sign'] = true,           -- cite interview
    ['cartography'] = true,
    ['chapter'] = true,
    ['chapter-format'] = true,
    ['chapterurl'] = true,
    ['chapter-url'] = true,
    ['city'] = true,                -- cite interview, cite episode, cite serial
    ['class'] = true,               -- cite arxiv and arxiv identifiers
    ['coauthor'] = false,           -- deprecated
    ['coauthors'] = false,          -- deprecated
    ['conference'] = true,
    ['conference-format'] = true,
    ['conferenceurl'] = true,
    ['conference-url'] = true,
    ['contribution'] = true,
    ['contribution-format'] = true,
    ['contributionurl'] = true,
    ['contribution-url'] = true,
    ['contributor'] = true,
    ['contributor-first'] = true,
    ['contributor-last'] = true,
    ['contributor-link'] = true,
    ['contributor-mask'] = true,
    ['credits'] = true,             -- cite episode, cite serial
    ['date'] = true,
    ['deadurl'] = true,
    ['dead-url'] = true,
    ['degree'] = true,
    ['department'] = true,
    ['dictionary'] = true,
    ['displayauthors'] = true,
    ['display-authors'] = true,
    ['displayeditors'] = true,
    ['display-editors'] = true,
    ['docket'] = true,
    ['doi'] = true,
    ['DOI'] = true,
    ['doi-broken'] = true,
    ['doi_brokendate'] = true,
    ['doi-broken-date'] = true,
    ['doi_inactivedate'] = true,
    ['doi-inactive-date'] = true,
    ['edition'] = true,
    ['editor'] = true,
    ['editor-first'] = true,
    ['editor-given'] = true,
    ['editor-last'] = true,
    ['editorlink'] = true,
    ['editor-link'] = true,
    ['editormask'] = true,
    ['editor-mask'] = true,
    ['editors'] = true,
    ['editor-surname'] = true,
    ['embargo'] = true,
    ['encyclopaedia'] = true,
    ['encyclopedia'] = true,
    ['entry'] = true,
    ['episode'] = true,                                                         -- cite serial only TODO: make available to cite episode?
    ['episodelink'] = true,                                                     -- cite episode and cite serial
    ['episode-link'] = true,                                                    -- cite episode and cite serial
    ['eprint'] = true,                                                          -- cite arxiv and arxiv identifiers
    ['event'] = true,
    ['event-format'] = true,
    ['eventurl'] = true,
    ['event-url'] = true,
    ['first'] = true,
    ['format'] = true,
    ['given'] = true,
    ['host'] = true,
    ['id'] = true,
    ['ID'] = true,
    ['ignoreisbnerror'] = true,
    ['ignore-isbn-error'] = true,
    ['in'] = true,
    ['inset'] = true,
    ['institution'] = true,
    ['interviewer'] = true,             --cite interview
    ['interviewers'] = true,            --cite interview
    ['isbn'] = true,
    ['ISBN'] = true,
    ['isbn13'] = true,
    ['ISBN13'] = true,
    ['ismn'] = true,
    ['ISMN'] = true,
    ['issn'] = true,
    ['ISSN'] = true,
    ['issue'] = true,
    ['jfm'] = true,
    ['JFM'] = true,
    ['journal'] = true,
    ['jstor'] = true,
    ['JSTOR'] = true,
    ['language'] = true,
    ['last'] = true,
    ['lastauthoramp'] = true,
    ['last-author-amp'] = true,
    ['laydate'] = true,
    ['lay-date'] = true,
    ['laysource'] = true,
    ['lay-source'] = true,
    ['laysummary'] = true,
    ['lay-summary'] = true,
    ['lay-format'] = true,
    ['layurl'] = true,
    ['lay-url'] = true,
    ['lccn'] = true,
    ['LCCN'] = true,
    ['location'] = true,
    ['magazine'] = true,
    ['mailinglist'] = true,             -- cite mailing list only
    ['mailing-list'] = true,            -- cite mailing list only
    ['map'] = true,                     -- cite map only
    ['map-format'] = true,              -- cite map only
    ['mapurl'] = true,                  -- cite map only
    ['map-url'] = true,                 -- cite map only
    ['medium'] = true,
    ['message-id'] = true,          -- cite newsgroup
    ['minutes'] = true,
    ['mode'] = true,
    ['mr'] = true,
    ['MR'] = true,
    ['name-list-format'] = true,
    ['network'] = true,
    ['newsgroup'] = true,
    ['newspaper'] = true,
    ['nocat'] = true,
    ['no-cat'] = true,
    ['nopp'] = true,
    ['no-pp'] = true,
    ['notracking'] = true,
    ['no-tracking'] = true,
    ['number'] = true,
    ['oclc'] = true,
    ['OCLC'] = true,
    ['ol'] = true,
    ['OL'] = true,
    ['origyear'] = true,
    ['orig-year'] = true,
    ['osti'] = true,
    ['OSTI'] = true,
    ['others'] = true,
    ['p'] = true,
    ['page'] = true,
    ['pages'] = true,
    ['people'] = true,
    ['periodical'] = true,
    ['place'] = true,
    ['pmc'] = true,
    ['PMC'] = true,
    ['pmid'] = true,
    ['PMID'] = true,
    ['postscript'] = true,
    ['pp'] = true,
    ['program'] = true,             -- cite interview
    ['publicationdate'] = true,
    ['publication-date'] = true,
    ['publicationplace'] = true,
    ['publication-place'] = true,
    ['publisher'] = true,
    ['quotation'] = true,
    ['quote'] = true,
    ['ref'] = true,
    ['registration'] = true,
    ['rfc'] = true,
    ['RFC'] = true,
    ['scale'] = true,
    ['script-chapter'] = true,
    ['script-title'] = true,
    ['season'] = true,
    ['section'] = true,
    ['section-format'] = true,
    ['sections'] = true,                    -- cite map only
    ['sectionurl'] = true,
    ['section-url'] = true,
    ['series'] = true,
    ['serieslink'] = true,
    ['series-link'] = true,
    ['seriesno'] = true,
    ['series-no'] = true,
    ['seriesnumber'] = true,
    ['series-number'] = true,
    ['series-separator'] = true,
    ['sheet'] = true,                                                           -- cite map only
    ['sheets'] = true,                                                          -- cite map only
    ['ssrn'] = true,
    ['SSRN'] = true,
    ['station'] = true,
    ['subject'] = true,
    ['subjectlink'] = true,
    ['subject-link'] = true,
    ['subscription'] = true,
    ['surname'] = true,
    ['template doc demo'] = true,
    ['template-doc-demo'] = true,
    ['time'] = true,
    ['timecaption'] = true,
    ['time-caption'] = true,
    ['title'] = true,
    ['titlelink'] = true,
    ['title-link'] = true,
    ['trans_chapter'] = true,
    ['trans-chapter'] = true,
    ['trans-map'] = true,
    ['transcript'] = true,
    ['transcript-format'] = true,
    ['transcripturl'] = true,
    ['transcript-url'] = true,
    ['trans_title'] = true,
    ['trans-title'] = true,
    ['translator'] = true,
    ['translator-first'] = true,
    ['translator-last'] = true,
    ['translator-link'] = true,
    ['translator-mask'] = true,
    ['type'] = true,
    ['url'] = true,
    ['URL'] = true,
    ['vauthors'] = true,
    ['veditors'] = true,
    ['version'] = true,
    ['via'] = true,
    ['volume'] = true,
    ['website'] = true,
    ['work'] = true,
    ['year'] = true,
    ['zbl'] = true,
    ['ZBL'] = true,
}

local numbered_arguments = {
    ['author#'] = true,
    ['author-first#'] = true,
    ['author#-first'] = true,
    ['author-last#'] = true,
    ['author#-last'] = true,
    ['author-link#'] = true,
    ['author#link'] = true,
    ['author#-link'] = true,
    ['authorlink#'] = true,
    ['author-mask#'] = true,
    ['author#mask'] = true,
    ['author#-mask'] = true,
    ['authormask#'] = true,
    ['contributor#'] = true,
    ['contributor-first#'] = true,
    ['contributor#-first'] = true,
    ['contributor-last#'] = true,
    ['contributor#-last'] = true,
    ['contributor-link#'] = true,
    ['contributor#-link'] = true,
    ['contributor-mask#'] = true,
    ['contributor#-mask'] = true,
    ['editor#'] = true,
    ['editor-first#'] = true,
    ['editor#-first'] = true,
    ['editor#-given'] = true,
    ['editor-given#'] = true,
    ['editor-last#'] = true,
    ['editor#-last'] = true,
    ['editor-link#'] = true,
    ['editor#link'] = true,
    ['editor#-link'] = true,
    ['editorlink#'] = true,
    ['editor-mask#'] = true,
    ['editor#mask'] = true,
    ['editor#-mask'] = true,
    ['editormask#'] = true,
    ['editor#-surname'] = true,
    ['editor-surname#'] = true,
    ['first#'] = true,
    ['given#'] = true,
    ['last#'] = true,
    ['subject#'] = true,
    ['subject-link#'] = true,
    ['subject#link'] = true,
    ['subject#-link'] = true,
    ['subjectlink#'] = true,
    ['surname#'] = true,
    ['translator#'] = true,
    ['translator-first#'] = true,
    ['translator#-first'] = true,
    ['translator-last#'] = true,
    ['translator#-last'] = true,
    ['translator-link#'] = true,
    ['translator#-link'] = true,
    ['translator-mask#'] = true,
    ['translator#-mask'] = true,
}

local whitelist = {basic_arguments = basic_arguments, numbered_arguments = numbered_arguments};

--[[--------------------------< I S _ S E T >------------------------------------------------------------------

Returns true if argument is set; false otherwise. Argument is 'set' when it exists (not nil) or when it is not an empty string.
This function is global because it is called from both this module and from Date validation

]]
function is_set( var )
    return not (var == nil or var == '');
end

--[[--------------------------< F I R S T _ S E T >------------------------------------------------------------

Locates and returns the first set value in a table of values where the order established in the table,
left-to-right (or top-to-bottom), is the order in which the values are evaluated.  Returns nil if none are set.

This version replaces the original 'for _, val in pairs do' and a similar version that used ipairs.  With the pairs
version the order of evaluation could not be guaranteed.  With the ipairs version, a nil value would terminate
the for-loop before it reached the actual end of the list.

]]

local function first_set (list, count)
    local i = 1;
    while i <= count do                                                         -- loop through all items in list
        if is_set( list[i] ) then
            return list[i];                                                     -- return the first set list member
        end
        i = i + 1;                                                              -- point to next
    end
end

--[[--------------------------< I N _ A R R A Y >--------------------------------------------------------------

Whether needle is in haystack

]]

local function in_array( needle, haystack )
    if needle == nil then
        return false;
    end
    for n,v in ipairs( haystack ) do
        if v == needle then
            return n;
        end
    end
    return false;
end

--[[--------------------------< S U B S T I T U T E >----------------------------------------------------------

Populates numbered arguments in a message string using an argument table.

]]

local function substitute( msg, args )
    return msg; -- TODO: args and export_message_newRawMessage( msg, args ):plain() or msg;
end

--[[--------------------------< E R R O R _ C O M M E N T >----------------------------------------------------

Wraps error messages with css markup according to the state of hidden.

]]
local function error_comment( content, hidden )
    return substitute( hidden and cfg.presentation['hidden-error'] or cfg.presentation['visible-error'], content );
end

--[[--------------------------< S E T _ E R R O R >--------------------------------------------------------------

Sets an error condition and returns the appropriate error message.  The actual placement of the error message in the output is
the responsibility of the calling function.

]]
local function set_error( error_id, arguments, raw, prefix, suffix )
    local error_state = cfg.error_conditions[ error_id ];
    
    prefix = prefix or "";
    suffix = suffix or "";
    
    if error_state == nil then
        error( cfg.messages['undefined_error'] );
    elseif is_set( error_state.category ) then
        table.insert( z.error_categories, error_state.category );
    end
    
    local message = substitute( error_state.message, arguments );
    
    message = message .. " ([[" .. cfg.messages['help page link'] .. 
        "#" .. error_state.anchor .. "|" ..
        cfg.messages['help page label'] .. "]])";
    
    z.error_ids[ error_id ] = true;
    if in_array( error_id, { 'bare_url_missing_title', 'trans_missing_title' } )
            and z.error_ids['citation_missing_title'] then
        return '', false;
    end
    
    message = table.concat({ prefix, message, suffix });
    
    if raw == true then
        return message, error_state.hidden;
    end     
        
    return error_comment( message, error_state.hidden );
end

--[[--------------------------< A D D _ M A I N T _ C A T >------------------------------------------------------

Adds a category to z.maintenance_cats using names from the configuration file with additional text if any.
To prevent duplication, the added_maint_cats table lists the categories by key that have been added to z.maintenance_cats.

]]

local added_maint_cats = {}                                                     -- list of maintenance categories that have been added to z.maintenance_cats
local function add_maint_cat (key, arguments)
    if not added_maint_cats [key] then
        added_maint_cats [key] = true;                                          -- note that we've added this category
        table.insert( z.maintenance_cats, substitute (cfg.maint_cats [key], arguments));    -- make name then add to table
    end
end

--[[--------------------------< A D D _ P R O P _ C A T >--------------------------------------------------------

Adds a category to z.properties_cats using names from the configuration file with additional text if any.

]]

local added_prop_cats = {}                                                      -- list of property categories that have been added to z.properties_cats
local function add_prop_cat (key, arguments)
    if not added_prop_cats [key] then
        added_prop_cats [key] = true;                                           -- note that we've added this category
        table.insert( z.properties_cats, substitute (cfg.prop_cats [key], arguments));      -- make name then add to table
    end
end

--[[--------------------------< A D D _ V A N C _ E R R O R >----------------------------------------------------

Adds a single Vancouver system error message to the template's output regardless of how many error actually exist.
To prevent duplication, added_vanc_errs is nil until an error message is emitted.

]]

local added_vanc_errs;                                                          -- flag so we only emit one Vancouver error / category
local function add_vanc_error ()
    if not added_vanc_errs then
        added_vanc_errs = true;                                                 -- note that we've added this category
        table.insert( z.message_tail, { set_error( 'vancouver', {}, true ) } );
    end
end


--[[--------------------------< I S _ S C H E M E >------------------------------------------------------------

does this thing that purports to be a uri scheme seem to be a valid scheme?  The scheme is checked to see if it
is in agreement with http://tools.ietf.org/html/std66#section-3.1 which says:
    Scheme names consist of a sequence of characters beginning with a
   letter and followed by any combination of letters, digits, plus
   ("+"), period ("."), or hyphen ("-").

returns true if it does, else false

]]

local function is_scheme (scheme)
    return scheme and scheme:match ('^%a[%a%d%+%.%-]*:');                       -- true if scheme is set and matches the pattern
end


--[=[-------------------------< I S _ D O M A I N _ N A M E >--------------------------------------------------

Does this thing that purports to be a domain name seem to be a valid domain name?

Syntax defined here: http://tools.ietf.org/html/rfc1034#section-3.5
BNF defined here: https://tools.ietf.org/html/rfc4234
Single character names are generally reserved; see https://tools.ietf.org/html/draft-ietf-dnsind-iana-dns-01#page-15;
    see also [[Single-letter second-level domain]]
list of tlds: https://www.iana.org/domains/root/db

rfc952 (modified by rfc 1123) requires the first and last character of a hostname to be a letter or a digit.  Between
the first and last characters the name may use letters, digits, and the hyphen.

Also allowed are IPv4 addresses. IPv6 not supported

domain is expected to be stripped of any path so that the last character in the last character of the tld.  tld
is two or more alpha characters.  Any preceding '//' (from splitting a url with a scheme) will be stripped
here.  Perhaps not necessary but retained incase it is necessary for IPv4 dot decimal.

There are several tests:
    the first character of the whole domain name including subdomains must be a letter or a digit
    single-letter/digit second-level domains in the .org TLD
    q, x, and z SL domains in the .com TLD
    i and q SL domains in the .net TLD
    single-letter SL domains in the ccTLDs (where the ccTLD is two letters)
    two-character SL domains in gTLDs (where the gTLD is two or more letters)
    three-plus-character SL domains in gTLDs (where the gTLD is two or more letters)
    IPv4 dot-decimal address format; TLD not allowed

returns true if domain appears to be a proper name and tld or IPv4 address, else false

]=]

local function is_domain_name (domain)
    if not domain then
        return false;                                                           -- if not set, abandon
    end
    
    domain = domain:gsub ('^//', '');                                           -- strip '//' from domain name if present; done here so we only have to do it once
    
    if not domain:match ('^[%a%d]') then                                        -- first character must be letter or digit
        return false;
    end
    
    if domain:match ('%f[%a%d][%a%d]%.org$') then                               -- one character .org hostname
        return true;
    elseif domain:match ('%f[%a][qxz]%.com$') then                              -- assigned one character .com hostname (x.com times out 2015-12-10)
        return true;
    elseif domain:match ('%f[%a][iq]%.net$') then                               -- assigned one character .net hostname (q.net registered but not active 2015-12-10)
        return true;
    elseif domain:match ('%f[%a%d][%a%d]%.%a%a$') then                          -- one character hostname and cctld (2 chars)
        return true;
    elseif domain:match ('%f[%a%d][%a%d][%a%d]%.%a%a+$') then                   -- two character hostname and tld
        return true;
    elseif domain:match ('%f[%a%d][%a%d][%a%d%-]+[%a%d]%.%a%a+$') then          -- three or more character hostname.hostname or hostname.tld
        return true;
    elseif domain:match ('^%d%d?%d?%.%d%d?%d?%.%d%d?%d?%.%d%d?%d?') then        -- IPv4 address
        return true;
    else
        return false;
    end
end


--[[--------------------------< I S _ U R L >------------------------------------------------------------------

returns true if the scheme and domain parts of a url appear to be a valid url; else false.

This function is the last step in the validation process.  This function is separate because there are cases that
are not covered by split_url(), for example is_parameter_ext_wikilink() which is looking for bracketted external
wikilinks.

]]

local function is_url (scheme, domain)
    if is_set (scheme) then                                                     -- if scheme is set check it and domain
        return is_scheme (scheme) and is_domain_name (domain);
    else
        return is_domain_name (domain);                                         -- scheme not set when url is protocol relative
    end
end


--[[--------------------------< S P L I T _ U R L >------------------------------------------------------------

Split a url into a scheme, authority indicator, and domain.
If protocol relative url, return nil scheme and domain else return nil for both scheme and domain.

When not protocol relative, get scheme, authority indicator, and domain.  If there is an authority indicator (one
or more '/' characters following the scheme's colon), make sure that there are only 2.

]]

local function split_url (url_str)
    local scheme, authority, domain;
    
    url_str = url_str:gsub ('(%a)/.*', '%1');                                   -- strip path information (the capture prevents false replacement of '//')

    if url_str:match ('^//%S*') then                                            -- if there is what appears to be a protocol relative url
        domain = url_str:match ('^//(%S*)')
    elseif url_str:match ('%S-:/*%S+') then                                     -- if there is what appears to be a scheme, optional authority indicator, and domain name
        scheme, authority, domain = url_str:match ('(%S-:)(/*)(%S+)');          -- extract the scheme, authority indicator, and domain portions
        authority = authority:gsub ('//', '', 1);                               -- replace place 1 pair of '/' with nothing;
        if is_set(authority) then                                               -- if anything left (1 or 3+ '/' where authority should be) then
            domain = nil;                                                       -- set to nil which will cause an error message
        end
    end
    
    return scheme, domain;
end


--[[--------------------------< L I N K _ P A R A M _ O K >---------------------------------------------------

checks the content of |title-link=, |series-link=, |author-link= etc for properly formatted content: no wikilinks, no urls

Link parameters are to hold the title of a wikipedia article so none of the WP:TITLESPECIALCHARACTERS are allowed:
    # < > [ ] | { } _
except the underscore which is used as a space in wiki urls and # which is used for section links

returns false when the value contains any of these characters.

When there are no illegal characters, this function returns TRUE if value DOES NOT appear to be a valid url (the
|<param>-link= parameter is ok); else false when value appears to be a valid url (the |<param>-link= parameter is NOT ok).

]]

local function link_param_ok (value)
    local scheme, domain;
    if value:find ('[<>%[%]|{}]') then                                          -- if any prohibited characters
        return false;
    end

    scheme, domain = split_url (value);                                         -- get scheme or nil and domain or nil from url; 
    return not is_url (scheme, domain);                                         -- return true if value DOES NOT appear to be a valid url
end


--[[--------------------------< C H E C K _ U R L >------------------------------------------------------------

Determines whether a URL string appears to be valid.

First we test for space characters.  If any are found, return false.  Then split the url into scheme and domain
portions, or for protocol relative (//example.com) urls, just the domain.  Use is_url() to validate the two
portions of the url.  If both are valid, or for protocol relative if domain is valid, return true, else false.

]]

local function check_url( url_str )
    if nil == url_str:match ("^%S+$") then                                      -- if there are any spaces in |url=value it can't be a proper url
        return false;
    end
    local scheme, domain;

    scheme, domain = split_url (url_str);                                       -- get scheme or nil and domain or nil from url; 
    return is_url (scheme, domain);                                             -- return true if value appears to be a valid url
end


--[=[-------------------------< I S _ P A R A M E T E R _ E X T _ W I K I L I N K >----------------------------

Return true if a parameter value has a string that begins and ends with square brackets [ and ] and the first
non-space characters following the opening bracket appear to be a url.  The test will also find external wikilinks
that use protocol relative urls. Also finds bare urls.

The frontier pattern prevents a match on interwiki links which are similar to scheme:path urls.  The tests that
find bracketed urls are required because the parameters that call this test (currently |title=, |chapter=, |work=,
and |publisher=) may have wikilinks and there are articles or redirects like '//Hus' so, while uncommon, |title=[[//Hus]]
is possible as might be [[en://Hus]].

]=]

local function is_parameter_ext_wikilink (value)
local scheme, domain;

    value = value:gsub ('([^%s/])/[%a%d].*', '%1');                             -- strip path information (the capture prevents false replacement of '//')

    if value:match ('%f[%[]%[%a%S*:%S+.*%]') then                               -- if ext wikilink with scheme and domain: [xxxx://yyyyy.zzz]
        scheme, domain = value:match ('%f[%[]%[(%a%S*:)(%S+).*%]')
    elseif value:match ('%f[%[]%[//%S*%.%S+.*%]') then                          -- if protocol relative ext wikilink: [//yyyyy.zzz]
        domain = value:match ('%f[%[]%[//(%S*%.%S+).*%]');
    elseif value:match ('%a%S*:%S+') then                                       -- if bare url with scheme; may have leading or trailing plain text
        scheme, domain = value:match ('(%a%S*:)(%S+)');
    elseif value:match ('//%S*%.%S+') then                                      -- if protocol relative bare url: //yyyyy.zzz; may have leading or trailing plain text
        domain = value:match ('//(%S*%.%S+)');                                  -- what is left should be the domain
    else
        return false;                                                           -- didn't find anything that is obviously a url
    end

    return is_url (scheme, domain);                                             -- return true if value appears to be a valid url
end


--[[-------------------------< C H E C K _ F O R _ U R L >-----------------------------------------------------

loop through a list of parameters and their values.  Look at the value and if it has an external link, emit an error message.

]]

local function check_for_url (parameter_list)
local error_message = '';
    for k, v in pairs (parameter_list) do                                       -- for each parameter in the list
        if is_parameter_ext_wikilink (v) then                                   -- look at the value; if there is a url add an error message
            if is_set(error_message) then                                       -- once we've added the first portion of the error message ...
                error_message=error_message .. ", ";                            -- ... add a comma space separator
            end
            error_message=error_message .. "&#124;" .. k .. "=";                -- add the failed parameter
        end
    end
    if is_set (error_message) then                                              -- done looping, if there is an error message, display it
        table.insert( z.message_tail, { set_error( 'param_has_ext_link', {error_message}, true ) } );
    end
end


--[[--------------------------< S A F E _ F O R _ I T A L I C S >----------------------------------------------

Protects a string that will be wrapped in wiki italic markup '' ... ''

Note: We cannot use <i> for italics, as the expected behavior for italics specified by ''...'' in the title is that
they will be inverted (i.e. unitalicized) in the resulting references.  In addition, <i> and '' tend to interact
poorly under Mediawiki's HTML tidy.

]]

local function safe_for_italics( str )
    if not is_set(str) then
        return str;
    else
        if str:sub(1,1) == "'" then str = "<span />" .. str; end
        if str:sub(-1,-1) == "'" then str = str .. "<span />"; end
        
        -- Remove newlines as they break italics.
        return str:gsub( '\n', ' ' );
    end
end

--[[--------------------------< S A F E _ F O R _ U R L >------------------------------------------------------

Escape sequences for content that will be used for URL descriptions

]]

local function safe_for_url( str )
    if str:match( "%[%[.-%]%]" ) ~= nil then 
        table.insert( z.message_tail, { set_error( 'wikilink_in_url', {}, true ) } );
    end
    
    return str:gsub( '[%[%]\n]', {  
        ['['] = '&#91;',
        [']'] = '&#93;',
        ['\n'] = ' ' } );
end

--[[--------------------------< W R A P _ S T Y L E >----------------------------------------------------------

Applies styling to various parameters.  Supplied string is wrapped using a message_list configuration taking one
argument; protects italic styled parameters.  Additional text taken from citation_config.presentation - the reason
this function is similar to but separate from wrap_msg().

]]

local function wrap_style (key, str)
    if not is_set( str ) then
        return "";
    elseif in_array( key, { 'italic-title', 'trans-italic-title' } ) then
        str = safe_for_italics( str );
    end

    return substitute( cfg.presentation[key], {str} );
end

--[[--------------------------< E X T E R N A L _ L I N K >----------------------------------------------------

Format an external link with error checking

]]

local function external_link( URL, label, source )
    local error_str = "";
    if not is_set( label ) then
        label = URL;
        if is_set( source ) then
            error_str = set_error( 'bare_url_missing_title', { wrap_style ('parameter', source) }, false, " " );
        else
            error( cfg.messages["bare_url_no_origin"] );
        end         
    end
    if not check_url( URL ) then
        error_str = set_error( 'bad_url', {wrap_style ('parameter', source)}, false, " " ) .. error_str;
    end
    return table.concat({ "[", URL, " ", safe_for_url( label ), "]", error_str });
end

--[[--------------------------< E X T E R N A L _ L I N K _ I D >----------------------------------------------

Formats a wiki style external link

]]

local function external_link_id(options)
    local url_string = options.id;
    return '';
--    if options.encode == true or options.encode == nil then
--        url_string = export_uri_encode( url_string );
--    end
--    return export_ustring_format( '[[%s|%s]]%s[%s%s%s %s]',
--        options.link, options.label, options.separator or "&nbsp;",
--        options.prefix, url_string, options.suffix or "",
--        options.id --export_text_nowiki(options.id)
--    );
end

--[[--------------------------< D E P R E C A T E D _ P A R A M E T E R >--------------------------------------

Categorize and emit an error message when the citation contains one or more deprecated parameters.  The function includes the
offending parameter name to the error message.  Only one error message is emitted regardless of the number of deprecated
parameters in the citation.

]]

local page_in_deprecated_cat;                                                   -- sticky flag so that the category is added only once
local function deprecated_parameter(name)
    if not page_in_deprecated_cat then
        page_in_deprecated_cat = true;                                          -- note that we've added this category
        table.insert( z.message_tail, { set_error( 'deprecated_params', {name}, true ) } );     -- add error message
    end
end

--[[--------------------------< K E R N _ Q U O T E S >--------------------------------------------------------

Apply kerning to open the space between the quote mark provided by the Module and a leading or trailing quote mark contained in a |title= or |chapter= parameter's value.
This function will positive kern either single or double quotes:
    "'Unkerned title with leading and trailing single quote marks'"
    " 'Kerned title with leading and trailing single quote marks' " (in real life the kerning isn't as wide as this example)
Double single quotes (italic or bold wikimarkup) are not kerned.

Call this function for chapter titles, for website titles, etc; not for book titles.

]]

local function kern_quotes (str)
    local cap='';
    local cap2='';
    
    cap, cap2 = str:match ("^([\"\'])([^\'].+)");                               -- match leading double or single quote but not double single quotes
    if is_set (cap) then
        str = substitute (cfg.presentation['kern-left'], {cap, cap2});
    end

    cap, cap2 = str:match ("^(.+[^\'])([\"\'])$")
    if is_set (cap) then
        str = substitute (cfg.presentation['kern-right'], {cap, cap2});
    end
    return str;
end

--[[--------------------------< F O R M A T _ S C R I P T _ V A L U E >----------------------------------------

|script-title= holds title parameters that are not written in Latin based scripts: Chinese, Japanese, Arabic, Hebrew, etc. These scripts should
not be italicized and may be written right-to-left.  The value supplied by |script-title= is concatenated onto Title after Title has been wrapped
in italic markup.

Regardless of language, all values provided by |script-title= are wrapped in <bdi>...</bdi> tags to isolate rtl languages from the English left to right.

|script-title= provides a unique feature.  The value in |script-title= may be prefixed with a two-character ISO639-1 language code and a colon:
    |script-title=ja:*** *** (where * represents a Japanese character)
Spaces between the two-character code and the colon and the colon and the first script character are allowed:
    |script-title=ja : *** ***
    |script-title=ja: *** ***
    |script-title=ja :*** ***
Spaces preceding the prefix are allowed: |script-title = ja:*** ***

The prefix is checked for validity.  If it is a valid ISO639-1 language code, the lang attribute (lang="ja") is added to the <bdi> tag so that browsers can
know the language the tag contains.  This may help the browser render the script more correctly.  If the prefix is invalid, the lang attribute
is not added.  At this time there is no error message for this condition.

Supports |script-title= and |script-chapter=

TODO: error messages when prefix is invalid ISO639-1 code; when script_value has prefix but no script;
]]

local function format_script_value (script_value)
    local lang='';                                                              -- initialize to empty string
    local name;
    if script_value:match('^%l%l%s*:') then                                     -- if first 3 non-space characters are script language prefix
        lang = script_value:match('^(%l%l)%s*:%s*%S.*');                        -- get the language prefix or nil if there is no script
        if not is_set (lang) then
            return '';                                                          -- script_value was just the prefix so return empty string
        end
    end
    script_value = substitute (cfg.presentation['bdi'], {lang, script_value});  -- isolate in case script is rtl

    return script_value;
end

--[[--------------------------< S C R I P T _ C O N C A T E N A T E >------------------------------------------

Initially for |title= and |script-title=, this function concatenates those two parameter values after the script value has been 
wrapped in <bdi> tags.
]]

local function script_concatenate (title, script)
    if is_set (script) then
        script = format_script_value (script);                                  -- <bdi> tags, lang atribute, categorization, etc; returns empty string on error
        if is_set (script) then
            title = title .. ' ' .. script;                                     -- concatenate title and script title
        end
    end
    return title;
end


--[[--------------------------< W R A P _ M S G >--------------------------------------------------------------

Applies additional message text to various parameter values. Supplied string is wrapped using a message_list
configuration taking one argument.  Supports lower case text for {{citation}} templates.  Additional text taken
from citation_config.messages - the reason this function is similar to but separate from wrap_style().

]]

local function wrap_msg (key, str, lower)
    if not is_set( str ) then
        return "";
    end
    if true == lower then
        local msg;
        msg = cfg.messages[key]:lower();                                        -- set the message to lower case before 
        return substitute( msg, str );                                      -- including template text
    else
        return substitute( cfg.messages[key], str );
    end     
end


--[[-------------------------< I S _ A L I A S _ U S E D >-----------------------------------------------------

This function is used by select_one() to determine if one of a list of alias parameters is in the argument list
provided by the template.

Input:
    args – pointer to the arguments table from calling template
    alias – one of the list of possible aliases in the aliases lists from Module:Citation/CS1/Configuration
    index – for enumerated parameters, identifies which one
    enumerated – true/false flag used choose how enumerated aliases are examined
    value – value associated with an alias that has previously been selected; nil if not yet selected
    selected – the alias that has previously been selected; nil if not yet selected
    error_list – list of aliases that are duplicates of the alias already selected

Returns:
    value – value associated with alias we selected or that was previously selected or nil if an alias not yet selected
    selected – the alias we selected or the alias that was previously selected or nil if an alias not yet selected

]]

local function is_alias_used (args, alias, index, enumerated, value, selected, error_list)
    if enumerated then                                                          -- is this a test for an enumerated parameters?
        alias = alias:gsub ('#', index);                                        -- replace '#' with the value in index
    else
        alias = alias:gsub ('#', '');                                           -- remove '#' if it exists
    end

    if is_set(args[alias]) then                                                 -- alias is in the template's argument list
        if value ~= nil and selected ~= alias then                              -- if we have already selected one of the aliases
            local skip;
            for _, v in ipairs(error_list) do                                   -- spin through the error list to see if we've added this alias
                if v == alias then
                    skip = true;
                    break;                                                      -- has been added so stop looking 
                end
            end
            if not skip then                                                    -- has not been added so
                table.insert( error_list, alias );                              -- add error alias to the error list
            end
        else
            value = args[alias];                                                -- not yet selected an alias, so select this one
            selected = alias;
        end
    end
    return value, selected;                                                     -- return newly selected alias, or previously selected alias
end


--[[--------------------------< S E L E C T _ O N E >----------------------------------------------------------

Chooses one matching parameter from a list of parameters to consider.  The list of parameters to consider is just
names.  For parameters that may be enumerated, the position of the numerator in the parameter name is identified
by the '#' so |author-last1= and |author1-last= are represented as 'author-last#' and 'author#-last'.

Because enumerated parameter |<param>1= is an alias of |<param>= we must test for both possibilities.


Generates an error if more than one match is present.

]]

local function select_one( args, aliases_list, error_condition, index )
    local value = nil;                                                          -- the value assigned to the selected parameter
    local selected = '';                                                        -- the name of the parameter we have chosen
    local error_list = {};

    if index ~= nil then index = tostring(index); end

    for _, alias in ipairs( aliases_list ) do                                   -- for each alias in the aliases list
        if alias:match ('#') then                                               -- if this alias can be enumerated
            if '1' == index then                                                -- when index is 1 test for enumerated and non-enumerated aliases
                value, selected = is_alias_used (args, alias, index, false, value, selected, error_list);   -- first test for non-enumerated alias
            end
            value, selected = is_alias_used (args, alias, index, true, value, selected, error_list);        -- test for enumerated alias
        else
            value, selected = is_alias_used (args, alias, index, false, value, selected, error_list);       --test for non-enumerated alias
        end
    end

    if #error_list > 0 and 'none' ~= error_condition then                       -- for cases where this code is used outside of extract_names()
        local error_str = "";
        for _, k in ipairs( error_list ) do
            if error_str ~= "" then error_str = error_str .. cfg.messages['parameter-separator'] end
            error_str = error_str .. wrap_style ('parameter', k);
        end
        if #error_list > 1 then
            error_str = error_str .. cfg.messages['parameter-final-separator'];
        else
            error_str = error_str .. cfg.messages['parameter-pair-separator'];
        end
        error_str = error_str .. wrap_style ('parameter', selected);
        table.insert( z.message_tail, { set_error( error_condition, {error_str}, true ) } );
    end
    
    return value, selected;
end


--[[--------------------------< F O R M A T _ C H A P T E R _ T I T L E >--------------------------------------

Format the four chapter parameters: |script-chapter=, |chapter=, |trans-chapter=, and |chapter-url= into a single Chapter meta-
parameter (chapter_url_source used for error messages).

]]

local function format_chapter_title (scriptchapter, chapter, transchapter, chapterurl, chapter_url_source, no_quotes)
    local chapter_error = '';
    
    if not is_set (chapter) then
        chapter = '';                                                           -- to be safe for concatenation
    else
        if false == no_quotes then
            chapter = kern_quotes (chapter);                                        -- if necessary, separate chapter title's leading and trailing quote marks from Module provided quote marks
            chapter = wrap_style ('quoted-title', chapter);
        end
    end

    chapter = script_concatenate (chapter, scriptchapter)                       -- <bdi> tags, lang atribute, categorization, etc; must be done after title is wrapped

    if is_set (transchapter) then
        transchapter = wrap_style ('trans-quoted-title', transchapter);
        if is_set (chapter) then
            chapter = chapter ..  ' ' .. transchapter;
        else                                                                    -- here when transchapter without chapter or script-chapter
            chapter = transchapter;                                             -- 
            chapter_error = ' ' .. set_error ('trans_missing_title', {'chapter'});
        end
    end

    if is_set (chapterurl) then
        chapter = external_link (chapterurl, chapter, chapter_url_source);      -- adds bare_url_missing_title error if appropriate
    end

    return chapter .. chapter_error;
end

--[[--------------------------< H A S _ I N V I S I B L E _ C H A R S >----------------------------------------

This function searches a parameter's value for nonprintable or invisible characters.  The search stops at the
first match.

This function will detect the visible replacement character when it is part of the wikisource.

Detects but ignores nowiki and math stripmarkers.  Also detects other named stripmarkers (gallery, math, pre, ref)
and identifies them with a slightly different error message.  See also coins_cleanup().

Detects but ignores the character pattern that results from the transclusion of {{'}} templates.

Output of this function is an error message that identifies the character or the Unicode group, or the stripmarker
that was detected along with its position (or, for multi-byte characters, the position of its first byte) in the
parameter value.

]]

local function has_invisible_chars (param, v)
    -- Code deleted
    local i = 0;
    i = i + 1;
end


--[[--------------------------< A R G U M E N T _ W R A P P E R >----------------------------------------------

Argument wrapper.  This function provides support for argument mapping defined in the configuration file so that
multiple names can be transparently aliased to single internal variable.

]]

local function argument_wrapper( args )
    local origin = {};
    
    return setmetatable({
        ORIGIN = function( self, k )
            local dummy = self[k]; --force the variable to be loaded.
            return origin[k];
        end
    },
    {
        __index = function ( tbl, k )

            if origin[k] ~= nil then
                return nil;
            end
            
            local args, list, v = args, cfg.aliases[k];
            
            if type( list ) == 'table' then
                v, origin[k] = select_one( args, list, 'redundant_parameters' );
                if origin[k] == nil then
                    origin[k] = ''; -- Empty string, not nil
                end
            elseif list ~= nil then
                v, origin[k] = args[list], list;
            else
                -- maybe let through instead of raising an error?
                -- v, origin[k] = args[k], k;
                error( cfg.messages['unknown_argument_map'] );
            end
            
            -- Empty strings, not nil;
            if v == nil then
                v = cfg.defaults[k] or '';
                origin[k] = '';
            end

            tbl = rawset( tbl, k, v );
            return v;
        end,
    });
end

--[[--------------------------< V A L I D A T E >--------------------------------------------------------------
Looks for a parameter's name in the whitelist.

Parameters in the whitelist can have three values:
    true - active, supported parameters
    false - deprecated, supported parameters
    nil - unsupported parameters
    
]]

local function validate( name )
    local name = tostring( name );
    local state = whitelist.basic_arguments[ name ];
    
    -- Normal arguments
    if true == state then return true; end      -- valid actively supported parameter
    if false == state then
        deprecated_parameter (name);                -- parameter is deprecated but still supported
        return true;
    end
    
    -- Arguments with numbers in them
    name = name:gsub( "%d+", "#" );             -- replace digit(s) with # (last25 becomes last#
    state = whitelist.numbered_arguments[ name ];
    if true == state then return true; end      -- valid actively supported parameter
    if false == state then
        deprecated_parameter (name);                -- parameter is deprecated but still supported
        return true;
    end
    
    return false;                               -- Not supported because not found or name is set to nil
end


-- Formats a wiki style internal link
local function internal_link_id(options)
    return '';
--    return export_ustring_format( '[[%s|%s]]%s[[%s%s%s|%s]]',
--        options.link, options.label, options.separator or "&nbsp;",
--        options.prefix, options.id, options.suffix or "",
--        export_text_nowiki(options.id)
--    );
end


--[[--------------------------< N O W R A P _ D A T E >--------------------------------------------------------

When date is YYYY-MM-DD format wrap in nowrap span: <span ...>YYYY-MM-DD</span>.  When date is DD MMMM YYYY or is
MMMM DD, YYYY then wrap in nowrap span: <span ...>DD MMMM</span> YYYY or <span ...>MMMM DD,</span> YYYY

DOES NOT yet support MMMM YYYY or any of the date ranges.

]]

local function nowrap_date (date)
    local cap='';
    local cap2='';

    if date:match("^%d%d%d%d%-%d%d%-%d%d$") then
        date = substitute (cfg.presentation['nowrap1'], date);
    
    elseif date:match("^%a+%s*%d%d?,%s+%d%d%d%d$") or date:match ("^%d%d?%s*%a+%s+%d%d%d%d$") then
        cap, cap2 = string.match (date, "^(.*)%s+(%d%d%d%d)$");
        date = substitute (cfg.presentation['nowrap2'], {cap, cap2});
    end
    
    return date;
end

--[[--------------------------< IS _ V A L I D _ I S X N >-----------------------------------------------------

ISBN-10 and ISSN validator code calculates checksum across all isbn/issn digits including the check digit. ISBN-13 is checked in check_isbn().
If the number is valid the result will be 0. Before calling this function, issbn/issn must be checked for length and stripped of dashes,
spaces and other non-isxn characters.

]]

local function is_valid_isxn (isxn_str, len)
    local temp = 0;
    isxn_str = { isxn_str:byte(1, len) };   -- make a table of byte values '0' → 0x30 .. '9'  → 0x39, 'X' → 0x58
    len = len+1;                            -- adjust to be a loop counter
    for i, v in ipairs( isxn_str ) do       -- loop through all of the bytes and calculate the checksum
        if v == string.byte( "X" ) then     -- if checkdigit is X (compares the byte value of 'X' which is 0x58)
            temp = temp + 10*( len - i );   -- it represents 10 decimal
        else
            temp = temp + tonumber( string.char(v) )*(len-i);
        end
    end
    return temp % 11 == 0;                  -- returns true if calculation result is zero
end


--[[--------------------------< IS _ V A L I D _ I S X N  _ 1 3 >----------------------------------------------

ISBN-13 and ISMN validator code calculates checksum across all 13 isbn/ismn digits including the check digit.
If the number is valid, the result will be 0. Before calling this function, isbn-13/ismn must be checked for length
and stripped of dashes, spaces and other non-isxn-13 characters.

]]

local function is_valid_isxn_13 (isxn_str)
    local temp=0;
    
    isxn_str = { isxn_str:byte(1, 13) };                                        -- make a table of byte values '0' → 0x30 .. '9'  → 0x39
    for i, v in ipairs( isxn_str ) do
        temp = temp + (3 - 2*(i % 2)) * tonumber( string.char(v) );             -- multiply odd index digits by 1, even index digits by 3 and sum; includes check digit
    end
    return temp % 10 == 0;                                                      -- sum modulo 10 is zero when isbn-13/ismn is correct
end

--[[--------------------------< C H E C K _ I S B N >------------------------------------------------------------

Determines whether an ISBN string is valid

]]

local function check_isbn( isbn_str )
    if nil ~= isbn_str:match("[^%s-0-9X]") then return false; end       -- fail if isbn_str contains anything but digits, hyphens, or the uppercase X
    isbn_str = isbn_str:gsub( "-", "" ):gsub( " ", "" );    -- remove hyphens and spaces
    local len = isbn_str:len();
 
    if len ~= 10 and len ~= 13 then
        return false;
    end

    if len == 10 then
        if isbn_str:match( "^%d*X?$" ) == nil then return false; end
        return is_valid_isxn(isbn_str, 10);
    else
        local temp = 0;
        if isbn_str:match( "^97[89]%d*$" ) == nil then return false; end        -- isbn13 begins with 978 or 979; ismn begins with 979
        return is_valid_isxn_13 (isbn_str);
    end
end

--[[--------------------------< C H E C K _ I S M N >------------------------------------------------------------

Determines whether an ISMN string is valid.  Similar to isbn-13, ismn is 13 digits begining 979-0-... and uses the
same check digit calculations.  See http://www.ismn-international.org/download/Web_ISMN_Users_Manual_2008-6.pdf
section 2, pages 9–12.

]]

local function ismn (id)
    local handler = cfg.id_handlers['ISMN'];
    local text;
    local valid_ismn = true;

    id=id:gsub( "[%s-–]", "" );                                                 -- strip spaces, hyphens, and endashes from the ismn

    if 13 ~= id:len() or id:match( "^9790%d*$" ) == nil then                    -- ismn must be 13 digits and begin 9790
        valid_ismn = false;
    else
        valid_ismn=is_valid_isxn_13 (id);                                       -- validate ismn
    end

--  text = internal_link_id({link = handler.link, label = handler.label,        -- use this (or external version) when there is some place to link to
--      prefix=handler.prefix,id=id,separator=handler.separator, encode=handler.encode})
 
    text="[[" .. handler.link .. "|" .. handler.label .. "]]" .. handler.separator .. id;       -- because no place to link to yet

    if false == valid_ismn then
        text = text .. ' ' .. set_error( 'bad_ismn' )                           -- add an error message if the issn is invalid
    end 
    
    return text;
end

--[[--------------------------< I S S N >----------------------------------------------------------------------

Validate and format an issn.  This code fixes the case where an editor has included an ISSN in the citation but has separated the two groups of four
digits with a space.  When that condition occurred, the resulting link looked like this:

    |issn=0819 4327 gives: [http://www.worldcat.org/issn/0819 4327 0819 4327]  -- can't have spaces in an external link
    
This code now prevents that by inserting a hyphen at the issn midpoint.  It also validates the issn for length and makes sure that the checkdigit agrees
with the calculated value.  Incorrect length (8 digits), characters other than 0-9 and X, or checkdigit / calculated value mismatch will all cause a check issn
error message.  The issn is always displayed with a hyphen, even if the issn was given as a single group of 8 digits.

]]

local function issn(id)
    local issn_copy = id;       -- save a copy of unadulterated issn; use this version for display if issn does not validate
    local handler = cfg.id_handlers['ISSN'];
    local text;
    local valid_issn = true;

    id=id:gsub( "[%s-–]", "" );                                 -- strip spaces, hyphens, and endashes from the issn

    if 8 ~= id:len() or nil == id:match( "^%d*X?$" ) then       -- validate the issn: 8 digits long, containing only 0-9 or X in the last position
        valid_issn=false;                                       -- wrong length or improper character
    else
        valid_issn=is_valid_isxn(id, 8);                        -- validate issn
    end

    if true == valid_issn then
        id = string.sub( id, 1, 4 ) .. "-" .. string.sub( id, 5 );  -- if valid, display correctly formatted version
    else
        id = issn_copy;                                         -- if not valid, use the show the invalid issn with error message
    end
    
    text = external_link_id({link = handler.link, label = handler.label,
        prefix=handler.prefix,id=id,separator=handler.separator, encode=handler.encode})
 
    if false == valid_issn then
        text = text .. ' ' .. set_error( 'bad_issn' )           -- add an error message if the issn is invalid
    end 
    
    return text
end

--[[--------------------------< A M A Z O N >------------------------------------------------------------------

Formats a link to Amazon.  Do simple error checking: asin must be mix of 10 numeric or uppercase alpha
characters.  If a mix, first character must be uppercase alpha; if all numeric, asins must be 10-digit
isbn. If 10-digit isbn, add a maintenance category so a bot or awb script can replace |asin= with |isbn=.
Error message if not 10 characters, if not isbn10, if mixed and first character is a digit.

]]

local function amazon(id, domain)
    local err_cat = ""

    if not id:match("^[%d%u][%d%u][%d%u][%d%u][%d%u][%d%u][%d%u][%d%u][%d%u][%d%u]$") then
        err_cat =  ' ' .. set_error ('bad_asin');                               -- asin is not a mix of 10 uppercase alpha and numeric characters
    else
        if id:match("^%d%d%d%d%d%d%d%d%d[%dX]$") then                               -- if 10-digit numeric (or 9 digits with terminal X)
            if check_isbn( id ) then                                                -- see if asin value is isbn10
                add_maint_cat ('ASIN');
            elseif not is_set (err_cat) then
                err_cat =  ' ' .. set_error ('bad_asin');                       -- asin is not isbn10
            end
        elseif not id:match("^%u[%d%u]+$") then
            err_cat =  ' ' .. set_error ('bad_asin');                           -- asin doesn't begin with uppercase alpha
        end
    end
    if not is_set(domain) then 
        domain = "com";
    elseif in_array (domain, {'jp', 'uk'}) then         -- Japan, United Kingdom
        domain = "co." .. domain;
    elseif in_array (domain, {'au', 'br', 'mx'}) then   -- Australia, Brazil, Mexico
        domain = "com." .. domain;
    end
    local handler = cfg.id_handlers['ASIN'];
    return external_link_id({link=handler.link,
        label=handler.label, prefix=handler.prefix .. domain .. "/dp/",
        id=id, encode=handler.encode, separator = handler.separator}) .. err_cat;
end

--[[--------------------------< A R X I V >--------------------------------------------------------------------

See: http://arxiv.org/help/arxiv_identifier

format and error check arXiv identifier.  There are three valid forms of the identifier:
the first form, valid only between date codes 9108 and 0703 is:
    arXiv:<archive>.<class>/<date code><number><version>
where:
    <archive> is a string of alpha characters - may be hyphenated; no other punctuation
    <class> is a string of alpha characters - may be hyphenated; no other punctuation
    <date code> is four digits in the form YYMM where YY is the last two digits of the four-digit year and MM is the month number January = 01
        first digit of YY for this form can only 9 and 0
    <number> is a three-digit number
    <version> is a 1 or more digit number preceded with a lowercase v; no spaces (undocumented)
    
the second form, valid from April 2007 through December 2014 is:
    arXiv:<date code>.<number><version>
where:
    <date code> is four digits in the form YYMM where YY is the last two digits of the four-digit year and MM is the month number January = 01
    <number> is a four-digit number
    <version> is a 1 or more digit number preceded with a lowercase v; no spaces

the third form, valid from January 2015 is:
    arXiv:<date code>.<number><version>
where:
    <date code> and <version> are as defined for 0704-1412
    <number> is a five-digit number
]]

local function arxiv (id, class)
    local handler = cfg.id_handlers['ARXIV'];
    local year, month, version;
    local err_cat = '';
    local text;
    
    if id:match("^%a[%a%.%-]+/[90]%d[01]%d%d%d%d$") or id:match("^%a[%a%.%-]+/[90]%d[01]%d%d%d%dv%d+$") then    -- test for the 9108-0703 format w/ & w/o version
        year, month = id:match("^%a[%a%.%-]+/([90]%d)([01]%d)%d%d%d[v%d]*$");
        year = tonumber(year);
        month = tonumber(month);
        if ((not (90 < year or 8 > year)) or (1 > month or 12 < month)) or      -- if invalid year or invalid month
            ((91 == year and 7 > month) or (7 == year and 3 < month)) then      -- if years ok, are starting and ending months ok?
                err_cat = ' ' .. set_error( 'bad_arxiv' );                      -- set error message
        end
    elseif id:match("^%d%d[01]%d%.%d%d%d%d$") or id:match("^%d%d[01]%d%.%d%d%d%dv%d+$") then    -- test for the 0704-1412 w/ & w/o version
        year, month = id:match("^(%d%d)([01]%d)%.%d%d%d%d[v%d]*$");
        year = tonumber(year);
        month = tonumber(month);
        if ((7 > year) or (14 < year) or (1 > month or 12 < month)) or          -- is year invalid or is month invalid? (doesn't test for future years)
            ((7 == year) and (4 > month)) then --or                                 -- when year is 07, is month invalid (before April)?
                err_cat = ' ' .. set_error( 'bad_arxiv' );                      -- set error message
        end
    elseif id:match("^%d%d[01]%d%.%d%d%d%d%d$") or id:match("^%d%d[01]%d%.%d%d%d%d%dv%d+$") then    -- test for the 1501- format w/ & w/o version
        year, month = id:match("^(%d%d)([01]%d)%.%d%d%d%d%d[v%d]*$");
        year = tonumber(year);
        month = tonumber(month);
        if ((15 > year) or (1 > month or 12 < month)) then                      -- is year invalid or is month invalid? (doesn't test for future years)
            err_cat = ' ' .. set_error( 'bad_arxiv' );                          -- set error message
        end
    else
        err_cat = ' ' .. set_error( 'bad_arxiv' );                              -- arXiv id doesn't match any format
    end

    text = external_link_id({link = handler.link, label = handler.label,
            prefix=handler.prefix,id=id,separator=handler.separator, encode=handler.encode}) .. err_cat;

    if is_set (class) then
        class = ' [[' .. '//arxiv.org/archive/' .. class .. ' ' .. class .. ']]';   -- external link within square brackets, not wikilink
    else
        class = '';                                                             -- empty string for concatenation
    end
    
    return text .. class;
end

--[[
lccn normalization (http://www.loc.gov/marc/lccn-namespace.html#normalization)
1. Remove all blanks.
2. If there is a forward slash (/) in the string, remove it, and remove all characters to the right of the forward slash.
3. If there is a hyphen in the string:
    a. Remove it.
    b. Inspect the substring following (to the right of) the (removed) hyphen. Then (and assuming that steps 1 and 2 have been carried out):
        1. All these characters should be digits, and there should be six or less. (not done in this function)
        2. If the length of the substring is less than 6, left-fill the substring with zeroes until the length is six.

Returns a normalized lccn for lccn() to validate.  There is no error checking (step 3.b.1) performed in this function.
]]

local function normalize_lccn (lccn)
    lccn = lccn:gsub ("%s", "");                                    -- 1. strip whitespace

    if nil ~= string.find (lccn,'/') then
        lccn = lccn:match ("(.-)/");                                -- 2. remove forward slash and all character to the right of it
    end

    local prefix
    local suffix
    prefix, suffix = lccn:match ("(.+)%-(.+)");                     -- 3.a remove hyphen by splitting the string into prefix and suffix

    if nil ~= suffix then                                           -- if there was a hyphen
        suffix=string.rep("0", 6-string.len (suffix)) .. suffix;    -- 3.b.2 left fill the suffix with 0s if suffix length less than 6
        lccn=prefix..suffix;                                        -- reassemble the lccn
    end
    
    return lccn;
    end

--[[
Format LCCN link and do simple error checking.  LCCN is a character string 8-12 characters long. The length of the LCCN dictates the character type of the first 1-3 characters; the
rightmost eight are always digits. http://info-uri.info/registry/OAIHandler?verb=GetRecord&metadataPrefix=reg&identifier=info:lccn/

length = 8 then all digits
length = 9 then lccn[1] is lower case alpha
length = 10 then lccn[1] and lccn[2] are both lower case alpha or both digits
length = 11 then lccn[1] is lower case alpha, lccn[2] and lccn[3] are both lower case alpha or both digits
length = 12 then lccn[1] and lccn[2] are both lower case alpha

]]

local function lccn(lccn)
    local handler = cfg.id_handlers['LCCN'];
    local err_cat =  '';                                -- presume that LCCN is valid
    local id = lccn;                                    -- local copy of the lccn

    id = normalize_lccn (id);                           -- get canonical form (no whitespace, hyphens, forward slashes)
    local len = id:len();                               -- get the length of the lccn

    if 8 == len then
        if id:match("[^%d]") then                       -- if LCCN has anything but digits (nil if only digits)
            err_cat = ' ' .. set_error( 'bad_lccn' );   -- set an error message
        end
    elseif 9 == len then                                -- LCCN should be adddddddd
        if nil == id:match("%l%d%d%d%d%d%d%d%d") then           -- does it match our pattern?
            err_cat = ' ' .. set_error( 'bad_lccn' );   -- set an error message
        end
    elseif 10 == len then                               -- LCCN should be aadddddddd or dddddddddd
        if id:match("[^%d]") then                           -- if LCCN has anything but digits (nil if only digits) ...
            if nil == id:match("^%l%l%d%d%d%d%d%d%d%d") then    -- ... see if it matches our pattern
                err_cat = ' ' .. set_error( 'bad_lccn' );   -- no match, set an error message
            end
        end
    elseif 11 == len then                               -- LCCN should be aaadddddddd or adddddddddd
        if not (id:match("^%l%l%l%d%d%d%d%d%d%d%d") or id:match("^%l%d%d%d%d%d%d%d%d%d%d")) then    -- see if it matches one of our patterns
            err_cat = ' ' .. set_error( 'bad_lccn' );   -- no match, set an error message
        end
    elseif 12 == len then                               -- LCCN should be aadddddddddd
        if not id:match("^%l%l%d%d%d%d%d%d%d%d%d%d") then   -- see if it matches our pattern
            err_cat = ' ' .. set_error( 'bad_lccn' );   -- no match, set an error message
        end
    else
        err_cat = ' ' .. set_error( 'bad_lccn' );       -- wrong length, set an error message
    end

    if not is_set (err_cat) and nil ~= lccn:find ('%s') then
        err_cat = ' ' .. set_error( 'bad_lccn' );       -- lccn contains a space, set an error message
    end

    return external_link_id({link = handler.link, label = handler.label,
            prefix=handler.prefix,id=lccn,separator=handler.separator, encode=handler.encode}) .. err_cat;
end

--[[
Format PMID and do simple error checking.  PMIDs are sequential numbers beginning at 1 and counting up.  This code checks the PMID to see that it
contains only digits and is less than test_limit; the value in local variable test_limit will need to be updated periodically as more PMIDs are issued.
]]

local function pmid(id)
    local test_limit = 30000000;                        -- update this value as PMIDs approach
    local handler = cfg.id_handlers['PMID'];
    local err_cat =  '';                                -- presume that PMID is valid
    
    if id:match("[^%d]") then                           -- if PMID has anything but digits
        err_cat = ' ' .. set_error( 'bad_pmid' );       -- set an error message
    else                                                -- PMID is only digits
        local id_num = tonumber(id);                    -- convert id to a number for range testing
        if 1 > id_num or test_limit < id_num then       -- if PMID is outside test limit boundaries
            err_cat = ' ' .. set_error( 'bad_pmid' );   -- set an error message
        end
    end
    
    return external_link_id({link = handler.link, label = handler.label,
            prefix=handler.prefix,id=id,separator=handler.separator, encode=handler.encode}) .. err_cat;
end

--[[--------------------------< I S _ E M B A R G O E D >------------------------------------------------------

Determines if a PMC identifier's online version is embargoed. Compares the date in |embargo= against today's date.  If embargo date is
in the future, returns the content of |embargo=; otherwise, returns and empty string because the embargo has expired or because
|embargo= was not set in this cite.

]]

local function is_embargoed (embargo)
    if is_set (embargo) then
        local lang = global_content_language;
        local good1, embargo_date, good2, todays_date;
        good1, embargo_date = pcall( lang.formatDate, lang, 'U', embargo );
        good2, todays_date = pcall( lang.formatDate, lang, 'U' );
    
        if good1 and good2 then                                                 -- if embargo date and today's date are good dates
            if tonumber( embargo_date ) >= tonumber( todays_date ) then         -- is embargo date is in the future?
                return embargo;                                                 -- still embargoed
            else
                add_maint_cat ('embargo')
                return '';                                                      -- unset because embargo has expired
            end
        end
    end
    return '';                                                                  -- |embargo= not set return empty string
end

--[[--------------------------< P M C >------------------------------------------------------------------------

Format a PMC, do simple error checking, and check for embargoed articles.

The embargo parameter takes a date for a value. If the embargo date is in the future the PMC identifier will not
be linked to the article.  If the embargo date is today or in the past, or if it is empty or omitted, then the
PMC identifier is linked to the article through the link at cfg.id_handlers['PMC'].prefix.

PMC embargo date testing is done in function is_embargoed () which is called earlier because when the citation
has |pmc=<value> but does not have a |url= then |title= is linked with the PMC link.  Function is_embargoed ()
returns the embargo date if the PMC article is still embargoed, otherwise it returns an empty string.

PMCs are sequential numbers beginning at 1 and counting up.  This code checks the PMC to see that it contains only digits and is less
than test_limit; the value in local variable test_limit will need to be updated periodically as more PMCs are issued.

]]

local function pmc(id, embargo)
    local test_limit = 5000000;                         -- update this value as PMCs approach
    local handler = cfg.id_handlers['PMC'];
    local err_cat =  '';                                -- presume that PMC is valid
    
    local text;

    if id:match("[^%d]") then                           -- if PMC has anything but digits
        err_cat = ' ' .. set_error( 'bad_pmc' );            -- set an error message
    else                                                -- PMC is only digits
        local id_num = tonumber(id);                    -- convert id to a number for range testing
        if 1 > id_num or test_limit < id_num then       -- if PMC is outside test limit boundaries
            err_cat = ' ' .. set_error( 'bad_pmc' );        -- set an error message
        end
    end
    
    if is_set (embargo) then                                                    -- is PMC is still embargoed?
        text="[[" .. handler.link .. "|" .. handler.label .. "]]:" .. handler.separator .. id .. err_cat;   -- still embargoed so no external link
    else
        text = external_link_id({link = handler.link, label = handler.label,            -- no embargo date or embargo has expired, ok to link to article
            prefix=handler.prefix,id=id,separator=handler.separator, encode=handler.encode}) .. err_cat;
    end
    return text;
end

-- Formats a DOI and checks for DOI errors.

-- DOI names contain two parts: prefix and suffix separated by a forward slash.
--  Prefix: directory indicator '10.' followed by a registrant code
--  Suffix: character string of any length chosen by the registrant

-- This function checks a DOI name for: prefix/suffix.  If the doi name contains spaces or endashes,
-- or, if it ends with a period or a comma, this function will emit a bad_doi error message.

-- DOI names are case-insensitive and can incorporate any printable Unicode characters so the test for spaces, endash,
-- and terminal punctuation may not be technically correct but it appears, that in practice these characters are rarely if ever used in doi names.

local function doi(id, inactive)
    local cat = ""
    local handler = cfg.id_handlers['DOI'];
    
    local text;
    if is_set(inactive) then
        local inactive_year = inactive:match("%d%d%d%d") or '';     -- try to get the year portion from the inactive date
        text = "[[" .. handler.link .. "|" .. handler.label .. "]]:" .. id;
        if is_set(inactive_year) then
            table.insert( z.error_categories, "Pages with DOIs inactive since " .. inactive_year );
        else
            table.insert( z.error_categories, "Pages with inactive DOIs" ); -- when inactive doesn't contain a recognizable year
        end
        inactive = " (" .. cfg.messages['inactive'] .. " " .. inactive .. ")" 
    else 
        text = external_link_id({link = handler.link, label = handler.label,
            prefix=handler.prefix,id=id,separator=handler.separator, encode=handler.encode})
        inactive = "" 
    end

    if nil == id:match("^10%.[^%s–]-/[^%s–]-[^%.,]$") then  -- doi must begin with '10.', must contain a fwd slash, must not contain spaces or endashes, and must not end with period or comma
        cat = ' ' .. set_error( 'bad_doi' );
    end
    return text .. inactive .. cat 
end


--[[--------------------------< O P E N L I B R A R Y >--------------------------------------------------------

Formats an OpenLibrary link, and checks for associated errors.

]]
local function openlibrary(id)
    local code = id:match("^%d+([AMW])$");                                      -- only digits followed by 'A', 'M', or 'W'
    local handler = cfg.id_handlers['OL'];

    if ( code == "A" ) then
        return external_link_id({link=handler.link, label=handler.label,
            prefix=handler.prefix .. 'authors/OL',
            id=id, separator=handler.separator, encode = handler.encode})
    elseif ( code == "M" ) then
        return external_link_id({link=handler.link, label=handler.label,
            prefix=handler.prefix .. 'books/OL',
            id=id, separator=handler.separator, encode = handler.encode})
    elseif ( code == "W" ) then
        return external_link_id({link=handler.link, label=handler.label,
            prefix=handler.prefix .. 'works/OL',
            id=id, separator=handler.separator, encode = handler.encode})
    else
        return external_link_id({link=handler.link, label=handler.label,
            prefix=handler.prefix .. 'OL',
            id=id, separator=handler.separator, encode = handler.encode}) .. ' ' .. set_error( 'bad_ol' );
    end
end


--[[--------------------------< M E S S A G E _ I D >----------------------------------------------------------

Validate and format a usenet message id.  Simple error checking, looks for 'id-left@id-right' not enclosed in
'<' and/or '>' angle brackets.

]]

local function message_id (id)
    local handler = cfg.id_handlers['USENETID'];

    text = external_link_id({link = handler.link, label = handler.label,
        prefix=handler.prefix,id=id,separator=handler.separator, encode=handler.encode})
 
    if not id:match('^.+@.+$') or not id:match('^[^<].*[^>]$')then              -- doesn't have '@' or has one or first or last character is '< or '>'
        text = text .. ' ' .. set_error( 'bad_message_id' )                     -- add an error message if the message id is invalid
    end 
    
    return text
end

--[[--------------------------< S E T _ T I T L E T Y P E >----------------------------------------------------

This function sets default title types (equivalent to the citation including |type=<default value>) for those templates that have defaults.
Also handles the special case where it is desirable to omit the title type from the rendered citation (|type=none).

]]

local function set_titletype (cite_class, title_type)
    if is_set(title_type) then
        if "none" == title_type then
            title_type = "";                                                    -- if |type=none then type parameter not displayed
        end
        return title_type;                                                      -- if |type= has been set to any other value use that value
    end

    return cfg.title_types [cite_class] or '';                                  -- set template's default title type; else empty string for concatenation
end

--[[--------------------------< C L E A N _ I S B N >----------------------------------------------------------

Removes irrelevant text and dashes from ISBN number
Similar to that used for Special:BookSources

]]

local function clean_isbn( isbn_str )
    return isbn_str:gsub( "[^-0-9X]", "" );
end

--[[--------------------------< E S C A P E _ L U A _ M A G I C _ C H A R S >----------------------------------

Returns a string where all of lua's magic characters have been escaped.  This is important because functions like
string.gsub() treat their pattern and replace strings as patterns, not literal strings.
]]
local function escape_lua_magic_chars (argument)
    argument = argument:gsub("%%", "%%%%");                                     -- replace % with %%
    argument = argument:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1");             -- replace all other lua magic pattern characters
    return argument;
end

--[[--------------------------< S T R I P _ A P O S T R O P H E _ M A R K U P >--------------------------------

Strip wiki italic and bold markup from argument so that it doesn't contaminate COinS metadata.
This function strips common patterns of apostrophe markup.  We presume that editors who have taken the time to
markup a title have, as a result, provided valid markup. When they don't, some single apostrophes are left behind.

]]

local function strip_apostrophe_markup (argument)
    if not is_set (argument) then return argument; end

    while true do
        if argument:match ("%'%'%'%'%'") then                                   -- bold italic (5)
            argument=argument:gsub("%'%'%'%'%'", "");                           -- remove all instances of it
        elseif argument:match ("%'%'%'%'") then                                 -- italic start and end without content (4)
            argument=argument:gsub("%'%'%'%'", "");
        elseif argument:match ("%'%'%'") then                                   -- bold (3)
            argument=argument:gsub("%'%'%'", "");
        elseif argument:match ("%'%'") then                                     -- italic (2)
            argument=argument:gsub("%'%'", "");
        else
            break;
        end
    end
    return argument;                                                            -- done
end

--[[--------------------------< M A K E _ C O I N S _ T I T L E >----------------------------------------------

Makes a title for COinS from Title and / or ScriptTitle (or any other name-script pairs)

Apostrophe markup (bold, italics) is stripped from each value so that the COinS metadata isn't correupted with strings
of %27%27...
]]

local function make_coins_title (title, script)
    if is_set (title) then
        title = strip_apostrophe_markup (title);                                -- strip any apostrophe markup
    else
        title='';                                                               -- if not set, make sure title is an empty string
    end
    if is_set (script) then
        script = script:gsub ('^%l%l%s*:%s*', '');                              -- remove language prefix if present (script value may now be empty string)
        script = strip_apostrophe_markup (script);                              -- strip any apostrophe markup
    else
        script='';                                                              -- if not set, make sure script is an empty string
    end
    if is_set (title) and is_set (script) then
        script = ' ' .. script;                                                 -- add a space before we concatenate
    end
    return title .. script;                                                     -- return the concatenation
end

--[[--------------------------< G E T _ C O I N S _ P A G E S >------------------------------------------------

Extract page numbers from external wikilinks in any of the |page=, |pages=, or |at= parameters for use in COinS.

]]

local function get_coins_pages (pages)
    local pattern;
    if not is_set (pages) then return pages; end                                -- if no page numbers then we're done
    
    while true do
        pattern = pages:match("%[(%w*:?//[^ ]+%s+)[%w%d].*%]");                 -- pattern is the opening bracket, the url and following space(s): "[url "
        if nil == pattern then break; end                                       -- no more urls
        pattern = escape_lua_magic_chars (pattern);                             -- pattern is not a literal string; escape lua's magic pattern characters
        pages = pages:gsub(pattern, "");                                        -- remove as many instances of pattern as possible
    end
    pages = pages:gsub("[%[%]]", "");                                           -- remove the brackets
    pages = pages:gsub("–", "-" );                          -- replace endashes with hyphens
    pages = pages:gsub("&%w+;", "-" );                      -- and replace html entities (&ndash; etc.) with hyphens; do we need to replace numerical entities like &#32; and the like?
    return pages;
end

-- Gets the display text for a wikilink like [[A|B]] or [[B]] gives B
local function remove_wiki_link( str )
    return (str:gsub( "%[%[([^%[%]]*)%]%]", function(l)
        return l:gsub( "^[^|]*|(.*)$", "%1" ):gsub("^%s*(.-)%s*$", "%1");
    end));
end

-- Converts a hyphen to a dash
local function hyphen_to_dash( str )
    if not is_set(str) or str:match( "[%[%]{}<>]" ) ~= nil then
        return str;
    end 
    return str:gsub( '-', '–' );
end

--[[--------------------------< S A F E _ J O I N >------------------------------------------------------------

Joins a sequence of strings together while checking for duplicate separation characters.

]]

local function safe_join( tbl, duplicate_char )
    --[[
    Note: we use string functions here, rather than ustring functions.
    
    This has considerably faster performance and should work correctly as 
    long as the duplicate_char is strict ASCII.  The strings
    in tbl may be ASCII or UTF8.
    ]]
    
    local str = '';                                                             -- the output string
    local comp = '';                                                            -- what does 'comp' mean?
    local end_chr = '';
    local trim;
    for _, value in ipairs( tbl ) do
        if value == nil then value = ''; end
        
        if str == '' then                                                       -- if output string is empty
            str = value;                                                        -- assign value to it (first time through the loop)
        elseif value ~= '' then
            if value:sub(1,1) == '<' then                                       -- Special case of values enclosed in spans and other markup.
                comp = value:gsub( "%b<>", "" );                                -- remove html markup (<span>string</span> -> string)
            else
                comp = value;
            end
                                                                                -- typically duplicate_char is sepc
            if comp:sub(1,1) == duplicate_char then                             -- is first charactier same as duplicate_char? why test first character?
                                                                                --   Because individual string segments often (always?) begin with terminal punct for th
                                                                                --   preceding segment: 'First element' .. 'sepc next element' .. etc?
                trim = false;
                end_chr = str:sub(-1,-1);                                       -- get the last character of the output string
                -- str = str .. "<HERE(enchr=" .. end_chr.. ")"                 -- debug stuff?
                if end_chr == duplicate_char then                               -- if same as separator
                    str = str:sub(1,-2);                                        -- remove it
                elseif end_chr == "'" then                                      -- if it might be wikimarkup
                    if str:sub(-3,-1) == duplicate_char .. "''" then            -- if last three chars of str are sepc'' 
                        str = str:sub(1, -4) .. "''";                           -- remove them and add back ''
                    elseif str:sub(-5,-1) == duplicate_char .. "]]''" then      -- if last five chars of str are sepc]]'' 
                        trim = true;                                            -- why? why do this and next differently from previous?
                    elseif str:sub(-4,-1) == duplicate_char .. "]''" then       -- if last four chars of str are sepc]'' 
                        trim = true;                                            -- same question
                    end
                elseif end_chr == "]" then                                      -- if it might be wikimarkup
                    if str:sub(-3,-1) == duplicate_char .. "]]" then            -- if last three chars of str are sepc]] wikilink 
                        trim = true;
                    elseif str:sub(-2,-1) == duplicate_char .. "]" then         -- if last two chars of str are sepc] external link
                        trim = true;
                    elseif str:sub(-4,-1) == duplicate_char .. "'']" then       -- normal case when |url=something & |title=Title.
                        trim = true;
                    end
                elseif end_chr == " " then                                      -- if last char of output string is a space
                    if str:sub(-2,-1) == duplicate_char .. " " then             -- if last two chars of str are <sepc><space>
                        str = str:sub(1,-3);                                    -- remove them both
                    end
                end

                if trim then
                    if value ~= comp then                                       -- value does not equal comp when value contains html markup
                        local dup2 = duplicate_char;
                        if dup2:match( "%A" ) then dup2 = "%" .. dup2; end      -- if duplicate_char not a letter then escape it
                        
                        value = value:gsub( "(%b<>)" .. dup2, "%1", 1 )         -- remove duplicate_char if it follows html markup
                    else
                        value = value:sub( 2, -1 );                             -- remove duplicate_char when it is first character
                    end
                end
            end
            str = str .. value;                                                 --add it to the output string
        end
    end
    return str;
end  

--[[--------------------------< I S _ G O O D _ V A N C _ N A M E >--------------------------------------------

For Vancouver Style, author/editor names are supposed to be rendered in Latin (read ASCII) characters.  When a name
uses characters that contain diacritical marks, those characters are to converted to the corresponding Latin character.
When a name is written using a non-Latin alphabet or logogram, that name is to be transliterated into Latin characters.
These things are not currently possible in this module so are left to the editor to do.

This test allows |first= and |last= names to contain any of the letters defined in the four Unicode Latin character sets
    [http://www.unicode.org/charts/PDF/U0000.pdf C0 Controls and Basic Latin] 0041–005A, 0061–007A
    [http://www.unicode.org/charts/PDF/U0080.pdf C1 Controls and Latin-1 Supplement] 00C0–00D6, 00D8–00F6, 00F8–00FF
    [http://www.unicode.org/charts/PDF/U0100.pdf Latin Extended-A] 0100–017F
    [http://www.unicode.org/charts/PDF/U0180.pdf Latin Extended-B] 0180–01BF, 01C4–024F

|lastn= also allowed to contain hyphens, spaces, and apostrophes. (http://www.ncbi.nlm.nih.gov/books/NBK7271/box/A35029/)
|firstn= also allowed to contain hyphens, spaces, apostrophes, and periods

At the time of this writing, I had to write the 'if nil == export_ustring_find ...' test ouside of the code editor and paste it here
because the code editor gets confused between character insertion point and cursor position.

]]

local function is_good_vanc_name (last, first)
 --   if nil == export_ustring_find (last, "^[A-Za-zÀ-ÖØ-öø-ƿǄ-ɏ%-%s%']*$") or nil == export_ustring_find (first, "^[A-Za-zÀ-ÖØ-öø-ƿǄ-ɏ%-%s%'%.]*$") then
--        add_vanc_error ();
--        return false;                                                           -- not a string of latin characters; Vancouver required Romanization
--    end;
    return true;
end

--[[--------------------------< R E D U C E _ T O _ I N I T I A L S >------------------------------------------

Attempts to convert names to initials in support of |name-list-format=vanc.  

Names in |firstn= may be separated by spaces or hyphens, or for initials, a period. See http://www.ncbi.nlm.nih.gov/books/NBK7271/box/A35062/.

Vancouver style requires family rank designations (Jr, II, III, etc) to be rendered as Jr, 2nd, 3rd, etc.  This form is not
currently supported by this code so correctly formed names like Smith JL 2nd are converted to Smith J2. See http://www.ncbi.nlm.nih.gov/books/NBK7271/box/A35085/.

This function uses ustring functions because firstname initials may be any of the unicode Latin characters accepted by is_good_vanc_name ().

]]

local function reduce_to_initials(first)
    if export_ustring_match(first, "^%u%u$") then return first end;                 -- when first contains just two upper-case letters, nothing to do
    local initials = {}
    local i = 0;                                                                -- counter for number of initials
    for word in export_ustring_gmatch(first, "[^%s%.%-]+") do                       -- names separated by spaces, hyphens, or periods
        table.insert(initials, export_ustring_sub(word,1,1))                        -- Vancouver format does not include full stops.
        i = i + 1;                                                              -- bump the counter 
        if 2 <= i then break; end                                               -- only two initials allowed in Vancouver system; if 2, quit
    end
    return table.concat(initials)                                               -- Vancouver format does not include spaces.
end

--[[--------------------------< L I S T  _ P E O P L E >-------------------------------------------------------

Formats a list of people (e.g. authors / editors) 

]]

local function list_people(control, people, etal, list_name)                    -- TODO: why is list_name here?  not used in this function
    local sep;
    local namesep;
    local format = control.format
    local maximum = control.maximum
    local lastauthoramp = control.lastauthoramp;
    local text = {}

    if 'vanc' == format then                                                    -- Vancouver-like author/editor name styling?
        sep = ',';                                                              -- name-list separator between authors is a comma
        namesep = ' ';                                                          -- last/first separator is a space
    else
        sep = ';'                                                               -- name-list separator between authors is a semicolon
        namesep = ', '                                                          -- last/first separator is <comma><space>
    end
    
    if sep:sub(-1,-1) ~= " " then sep = sep .. " " end
    if is_set (maximum) and maximum < 1 then return "", 0; end                  -- returned 0 is for EditorCount; not used for authors
    
    for i,person in ipairs(people) do
        if is_set(person.last) then
            local mask = person.mask
            local one
            local sep_one = sep;
            if is_set (maximum) and i > maximum then
                etal = true;
                break;
            elseif (mask ~= nil) then
                local n = tonumber(mask)
                if (n ~= nil) then
                    one = string.rep("&mdash;",n)
                else
                    one = mask;
                    sep_one = " ";
                end
            else
                one = person.last
                local first = person.first
                if is_set(first) then 
                    if ( "vanc" == format ) then                                -- if vancouver format
                        one = one:gsub ('%.', '');                              -- remove periods from surnames (http://www.ncbi.nlm.nih.gov/books/NBK7271/box/A35029/)
                        if not person.corporate and is_good_vanc_name (one, first) then                 -- and name is all Latin characters; corporate authors not tested
                            first = reduce_to_initials(first)                   -- attempt to convert first name(s) to initials
                        end
                    end
                    one = one .. namesep .. first 
                end
                if is_set(person.link) and person.link ~= control.page_name then
                    one = "[[" .. person.link .. "|" .. one .. "]]"             -- link author/editor if this page is not the author's/editor's page
                end
            end
            table.insert( text, one )
            table.insert( text, sep_one )
        end
    end

    local count = #text / 2;                                                    -- (number of names + number of separators) divided by 2
    if count > 0 then 
        if count > 1 and is_set(lastauthoramp) and not etal then
            text[#text-2] = " & ";                                              -- replace last separator with ampersand text
        end
        text[#text] = nil;                                                      -- erase the last separator
    end
    
    local result = table.concat(text)                                           -- construct list
    if etal and is_set (result) then                                            -- etal may be set by |display-authors=etal but we might not have a last-first list
        result = result .. sep .. ' ' .. cfg.messages['et al'];                 -- we've go a last-first list and etal so add et al.
    end
    
    return result, count
end

--[[--------------------------< A N C H O R _ I D >------------------------------------------------------------

Generates a CITEREF anchor ID if we have at least one name or a date.  Otherwise returns an empty string.

namelist is one of the contributor-, author-, or editor-name lists chosen in that order.  year is Year or anchor_year.

]]
local function anchor_id (namelist, year)
    local names={};                                                             -- a table for the one to four names and year
    for i,v in ipairs (namelist) do                                             -- loop through the list and take up to the first four last names
        names[i] = v.last 
        if i == 4 then break end                                                -- if four then done
    end
    table.insert (names, year);                                                 -- add the year at the end
    local id = table.concat(names);                                             -- concatenate names and year for CITEREF id
    if is_set (id) then                                                         -- if concatenation is not an empty string
        return "CITEREF" .. id;                                                 -- add the CITEREF portion
    else
        return '';                                                              -- return an empty string; no reason to include CITEREF id in this citation
    end
end


--[[--------------------------< N A M E _ H A S _ E T A L >----------------------------------------------------

Evaluates the content of author and editor name parameters for variations on the theme of et al.  If found,
the et al. is removed, a flag is set to true and the function returns the modified name and the flag.

This function never sets the flag to false but returns it's previous state because it may have been set by
previous passes through this function or by the parameters |display-authors=etal or |display-editors=etal

]]

local function name_has_etal (name, etal, nocat)

    if is_set (name) then                                                       -- name can be nil in which case just return
        local etal_pattern = "[;,]? *[\"']*%f[%a][Ee][Tt] *[Aa][Ll][%.\"']*$"   -- variations on the 'et al' theme
        local others_pattern = "[;,]? *%f[%a]and [Oo]thers";                    -- and alternate to et al.
        
        if name:match (etal_pattern) then                                       -- variants on et al.
            name = name:gsub (etal_pattern, '');                                -- if found, remove
            etal = true;                                                        -- set flag (may have been set previously here or by |display-authors=etal)
            if not nocat then                                                   -- no categorization for |vauthors=
                add_maint_cat ('etal');                                         -- and add a category if not already added
            end
        elseif name:match (others_pattern) then                                 -- if not 'et al.', then 'and others'?
            name = name:gsub (others_pattern, '');                              -- if found, remove
            etal = true;                                                        -- set flag (may have been set previously here or by |display-authors=etal)
            if not nocat then                                                   -- no categorization for |vauthors=
                add_maint_cat ('etal');                                         -- and add a category if not already added
            end
        end
    end
    return name, etal;                                                          -- 
end

--[[--------------------------< E X T R A C T _ N A M E S >----------------------------------------------------
Gets name list from the input arguments

Searches through args in sequential order to find |lastn= and |firstn= parameters (or their aliases), and their matching link and mask parameters.
Stops searching when both |lastn= and |firstn= are not found in args after two sequential attempts: found |last1=, |last2=, and |last3= but doesn't
find |last4= and |last5= then the search is done.

This function emits an error message when there is a |firstn= without a matching |lastn=.  When there are 'holes' in the list of last names, |last1= and |last3=
are present but |last2= is missing, an error message is emitted. |lastn= is not required to have a matching |firstn=.

When an author or editor parameter contains some form of 'et al.', the 'et al.' is stripped from the parameter and a flag (etal) returned
that will cause list_people() to add the static 'et al.' text from Module:Citation/CS1/Configuration.  This keeps 'et al.' out of the 
template's metadata.  When this occurs, the page is added to a maintenance category.

]]

local function extract_names(args, list_name)
    local names = {};           -- table of names
    local last;                 -- individual name components
    local first;
    local link;
    local mask;
    local i = 1;                -- loop counter/indexer
    local n = 1;                -- output table indexer
    local count = 0;            -- used to count the number of times we haven't found a |last= (or alias for authors, |editor-last or alias for editors)
    local etal=false;           -- return value set to true when we find some form of et al. in an author parameter

    local err_msg_list_name = list_name:match ("(%w+)List") .. 's list';        -- modify AuthorList or EditorList for use in error messages if necessary
    while true do
        last = select_one( args, cfg.aliases[list_name .. '-Last'], 'redundant_parameters', i );        -- search through args for name components beginning at 1
        first = select_one( args, cfg.aliases[list_name .. '-First'], 'redundant_parameters', i );
        link = select_one( args, cfg.aliases[list_name .. '-Link'], 'redundant_parameters', i );
        mask = select_one( args, cfg.aliases[list_name .. '-Mask'], 'redundant_parameters', i );

        last, etal = name_has_etal (last, etal, false);                             -- find and remove variations on et al.
        first, etal = name_has_etal (first, etal, false);                               -- find and remove variations on et al.

        if first and not last then                                              -- if there is a firstn without a matching lastn
            table.insert( z.message_tail, { set_error( 'first_missing_last', {err_msg_list_name, i}, true ) } );    -- add this error message
        elseif not first and not last then                                      -- if both firstn and lastn aren't found, are we done?
            count = count + 1;                                                  -- number of times we haven't found last and first
            if 2 <= count then                                                  -- two missing names and we give up
                break;                                                          -- normal exit or there is a two-name hole in the list; can't tell which
            end
        else                                                                    -- we have last with or without a first
            if is_set (link) and false == link_param_ok (link) then             -- do this test here in case link is missing last
                table.insert( z.message_tail, { set_error( 'bad_paramlink', list_name:match ("(%w+)List"):lower() .. '-link' .. i )});          -- url or wikilink in author link;
            end
            names[n] = {last = last, first = first, link = link, mask = mask, corporate=false}; -- add this name to our names list (corporate for |vauthors= only)
            n = n + 1;                                                          -- point to next location in the names table
            if 1 == count then                                                  -- if the previous name was missing
                table.insert( z.message_tail, { set_error( 'missing_name', {err_msg_list_name, i-1}, true ) } );        -- add this error message
            end
            count = 0;                                                          -- reset the counter, we're looking for two consecutive missing names
        end
        i = i + 1;                                                              -- point to next args location
    end
    
    return names, etal;                                                         -- all done, return our list of names
end

--[[--------------------------< B U I L D _ I D _ L I S T >--------------------------------------------------------

Populates ID table from arguments using configuration settings. Loops through cfg.id_handlers and searches args for
any of the parameters listed in each cfg.id_handlers['...'].parameters.  If found, adds the parameter and value to
the identifier list.  Emits redundant error message is more than one alias exists in args

]]

local function extract_ids( args )
    local id_list = {};                                                         -- list of identifiers found in args
    for k, v in pairs( cfg.id_handlers ) do                                     -- k is uc identifier name as index to cfg.id_handlers; e.g. cfg.id_handlers['ISBN'], v is a table
        v = select_one( args, v.parameters, 'redundant_parameters' );           -- v.parameters is a table of aliases for k; here we pick one from args if present
        if is_set(v) then id_list[k] = v; end                                   -- if found in args, add identifier to our list
    end
    return id_list;
end

--[[--------------------------< B U I L D _ I D _ L I S T >--------------------------------------------------------

Takes a table of IDs created by extract_ids() and turns it into a table of formatted ID outputs.

inputs:
    id_list – table of identifiers built by extract_ids()
    options – table of various template parameter values used to modify some manually handled identifiers

]]

local function build_id_list( id_list, options )
    local new_list, handler = {};

    function fallback(k) return { __index = function(t,i) return cfg.id_handlers[k][i] end } end;
    
    for k, v in pairs( id_list ) do                                             -- k is uc identifier name as index to cfg.id_handlers; e.g. cfg.id_handlers['ISBN'], v is a table
        -- fallback to read-only cfg
        handler = setmetatable( { ['id'] = v }, fallback(k) );
        
        if handler.mode == 'external' then
            table.insert( new_list, {handler.label, external_link_id( handler ) } );
        elseif handler.mode == 'internal' then
            table.insert( new_list, {handler.label, internal_link_id( handler ) } );
        elseif handler.mode ~= 'manual' then
            error( cfg.messages['unknown_ID_mode'] );
        elseif k == 'DOI' then
            table.insert( new_list, {handler.label, doi( v, options.DoiBroken ) } );
        elseif k == 'ARXIV' then
            table.insert( new_list, {handler.label, arxiv( v, options.Class ) } ); 
        elseif k == 'ASIN' then
            table.insert( new_list, {handler.label, amazon( v, options.ASINTLD ) } ); 
        elseif k == 'LCCN' then
            table.insert( new_list, {handler.label, lccn( v ) } );
        elseif k == 'OL' or k == 'OLA' then
            table.insert( new_list, {handler.label, openlibrary( v ) } );
        elseif k == 'PMC' then
            table.insert( new_list, {handler.label, pmc( v, options.Embargo ) } );
        elseif k == 'PMID' then
            table.insert( new_list, {handler.label, pmid( v ) } );
        elseif k == 'ISMN' then
            table.insert( new_list, {handler.label, ismn( v ) } );
        elseif k == 'ISSN' then
            table.insert( new_list, {handler.label, issn( v ) } );
        elseif k == 'ISBN' then
            local ISBN = internal_link_id( handler );
            if not check_isbn( v ) and not is_set(options.IgnoreISBN) then
                ISBN = ISBN .. set_error( 'bad_isbn', {}, false, " ", "" );
            end
            table.insert( new_list, {handler.label, ISBN } );               
        elseif k == 'USENETID' then
            table.insert( new_list, {handler.label, message_id( v ) } );
        else
            error( cfg.messages['unknown_manual_ID'] );
        end
    end
    
    function comp( a, b )   -- used in following table.sort()
        return a[1] < b[1];
    end
    
    table.sort( new_list, comp );
    for k, v in ipairs( new_list ) do
        new_list[k] = v[2];
    end
    
    return new_list;
end
  

--[[--------------------------< C O I N S _ C L E A N U P >----------------------------------------------------

Cleanup parameter values for the metadata by removing or replacing invisible characters and certain html entities.

2015-12-10: there is a bug in export_text_unstripNoWiki ().  It replaced math stripmarkers with the appropriate content
when it shouldn't.  See https://phabricator.wikimedia.org/T121085 and Wikipedia_talk:Lua#stripmarkers_and_export_text_unstripNoWiki.28.29

TODO: move the replacement patterns and replacement values into a table in /Configuration similar to the invisible
characters table?
]]

local function coins_cleanup (value)
    -- value = export_text_unstripNoWiki (value);                                      -- replace nowiki stripmarkers with their content
    value = value:gsub ('<span class="nowrap" style="padding%-left:0%.1em;">&#39;s</span>', "'s");  -- replace {{'s}} template with simple apostrophe-s
    value = value:gsub ('&zwj;\226\128\138\039\226\128\139', "'");              -- replace {{'}} with simple apostrophe
    value = value:gsub ('\226\128\138\039\226\128\139', "'");                   -- replace {{'}} with simple apostrophe (as of 2015-12-11)
    value = value:gsub ('&nbsp;', ' ');                                         -- replace &nbsp; entity with plain space
    value = value:gsub ('\226\128\138', ' ');                                   -- replace hair space with plain space
    value = value:gsub ('&zwj;', '');                                           -- remove &zwj; entities
    value = value:gsub ('[\226\128\141\226\128\139]', '')                       -- remove zero-width joiner, zero-width space
    value = value:gsub ('[\194\173\009\010\013]', ' ');                         -- replace soft hyphen, horizontal tab, line feed, carriage return with plain space
    return value;
end


--[[--------------------------< C O I N S >--------------------------------------------------------------------

COinS metadata (see <http://ocoins.info/>) allows automated tools to parse the citation information.

]]

local function COinS(data, class)
    if 'table' ~= type(data) or nil == next(data) then
        return '';
    end

    for k, v in pairs (data) do                                                 -- spin through all of the metadata parameter values
        if 'ID_list' ~= k and 'Authors' ~= k then                               -- except the ID_list and Author tables (author nowiki stripmarker done when Author table processed)
            data[k] = coins_cleanup (v);
        end
    end

    local ctx_ver = "Z39.88-2004";
    
    -- treat table strictly as an array with only set values.
    local OCinSoutput = setmetatable( {}, {
        __newindex = function(self, key, value)
            if is_set(value) then
                rawset( self, #self+1, table.concat{ key, '=', export_uri_encode( remove_wiki_link( value ) ) } );
            end
        end
    });
    
    if in_array (class, {'arxiv', 'journal', 'news'}) or (in_array (class, {'conference', 'interview', 'map', 'press release', 'web'}) and is_set(data.Periodical)) or 
        ('citation' == class and is_set(data.Periodical) and not is_set (data.Encyclopedia)) then
            OCinSoutput.rft_val_fmt = "info:ofi/fmt:kev:mtx:journal";           -- journal metadata identifier
            if 'arxiv' == class then                                            -- set genre according to the type of citation template we are rendering
                OCinSoutput["rft.genre"] = "preprint";                          -- cite arxiv
            elseif 'conference' == class then
                OCinSoutput["rft.genre"] = "conference";                        -- cite conference (when Periodical set)
            elseif 'web' == class then
                OCinSoutput["rft.genre"] = "unknown";                           -- cite web (when Periodical set)
            else
                OCinSoutput["rft.genre"] = "article";                           -- journal and other 'periodical' articles
            end
            OCinSoutput["rft.jtitle"] = data.Periodical;                        -- journal only
            if is_set (data.Map) then
                OCinSoutput["rft.atitle"] = data.Map;                           -- for a map in a periodical
            else
                OCinSoutput["rft.atitle"] = data.Title;                         -- all other 'periodical' article titles
            end
                                                                                -- these used onlu for periodicals
            OCinSoutput["rft.ssn"] = data.Season;                               -- keywords: winter, spring, summer, fall
            OCinSoutput["rft.chron"] = data.Chron;                              -- free-form date components
            OCinSoutput["rft.volume"] = data.Volume;                            -- does not apply to books
            OCinSoutput["rft.issue"] = data.Issue;
            OCinSoutput["rft.pages"] = data.Pages;                              -- also used in book metadata

    elseif 'thesis' ~= class then                                               -- all others except cite thesis are treated as 'book' metadata; genre distinguishes
        OCinSoutput.rft_val_fmt = "info:ofi/fmt:kev:mtx:book";                  -- book metadata identifier
        if 'report' == class or 'techreport' == class then                      -- cite report and cite techreport
            OCinSoutput["rft.genre"] = "report";
        elseif 'conference' == class then                                       -- cite conference when Periodical not set
            OCinSoutput["rft.genre"] = "conference";
        elseif in_array (class, {'book', 'citation', 'encyclopaedia', 'interview', 'map'}) then
            if is_set (data.Chapter) then
                OCinSoutput["rft.genre"] = "bookitem";
                OCinSoutput["rft.atitle"] = data.Chapter;                       -- book chapter, encyclopedia article, interview in a book, or map title
            else
                if 'map' == class or 'interview' == class then
                    OCinSoutput["rft.genre"] = 'unknown';                       -- standalone map or interview
                else
                    OCinSoutput["rft.genre"] = 'book';                          -- book and encyclopedia
                end
            end
        else    --{'audio-visual', 'AV-media-notes', 'DVD-notes', 'episode', 'interview', 'mailinglist', 'map', 'newsgroup', 'podcast', 'press release', 'serial', 'sign', 'speech', 'web'}
            OCinSoutput["rft.genre"] = "unknown";
        end
        OCinSoutput["rft.btitle"] = data.Title;                                 -- book only
        OCinSoutput["rft.place"] = data.PublicationPlace;                       -- book only
        OCinSoutput["rft.series"] = data.Series;                                -- book only
        OCinSoutput["rft.pages"] = data.Pages;                                  -- book, journal
        OCinSoutput["rft.edition"] = data.Edition;                              -- book only
        OCinSoutput["rft.pub"] = data.PublisherName;                            -- book and dissertation
        
    else                                                                        -- cite thesis
        OCinSoutput.rft_val_fmt = "info:ofi/fmt:kev:mtx:dissertation";          -- dissertation metadata identifier
        OCinSoutput["rft.title"] = data.Title;                                  -- dissertation (also patent but that is not yet supported)
        OCinSoutput["rft.degree"] = data.Degree;                                -- dissertation only
        OCinSoutput['rft.inst'] = data.PublisherName;                           -- book and dissertation
    end
                                                                                -- and now common parameters (as much as possible)
    OCinSoutput["rft.date"] = data.Date;                                        -- book, journal, dissertation
    
    for k, v in pairs( data.ID_list ) do                                        -- what to do about these? For now assume that they are common to all?
        if k == 'ISBN' then v = clean_isbn( v ) end
        local id = cfg.id_handlers[k].COinS;
        if string.sub( id or "", 1, 4 ) == 'info' then                          -- for ids that are in the info:registry
            OCinSoutput["rft_id"] = table.concat{ id, "/", v };
        elseif string.sub (id or "", 1, 3 ) == 'rft' then                       -- for isbn, issn, eissn, etc that have defined COinS keywords
            OCinSoutput[ id ] = v;
        elseif id then                                                          -- when cfg.id_handlers[k].COinS is not nil
            OCinSoutput["rft_id"] = table.concat{ cfg.id_handlers[k].prefix, v };   -- others; provide a url
        end
    end

--[[    
    for k, v in pairs( data.ID_list ) do                                        -- what to do about these? For now assume that they are common to all?
        local id, value = cfg.id_handlers[k].COinS;
        if k == 'ISBN' then value = clean_isbn( v ); else value = v; end
        if string.sub( id or "", 1, 4 ) == 'info' then
            OCinSoutput["rft_id"] = table.concat{ id, "/", v };
        else
            OCinSoutput[ id ] = value;
        end
    end
]]
    local last, first;
    for k, v in ipairs( data.Authors ) do
        last, first = coins_cleanup (v.last), coins_cleanup (v.first or '');    -- replace any nowiki strip markers, non-printing or invisible characers
        if k == 1 then                                                          -- for the first author name only
            if is_set(last)  and is_set(first) then                             -- set these COinS values if |first= and |last= specify the first author name
                OCinSoutput["rft.aulast"] = last;                               -- book, journal, dissertation
                OCinSoutput["rft.aufirst"] = first;                             -- book, journal, dissertation
            elseif is_set(last) then 
                OCinSoutput["rft.au"] = last;                                   -- book, journal, dissertation -- otherwise use this form for the first name
            end
        else                                                                    -- for all other authors
            if is_set(last) and is_set(first) then
                OCinSoutput["rft.au"] = table.concat{ last, ", ", first };      -- book, journal, dissertation
            elseif is_set(last) then
                OCinSoutput["rft.au"] = last;                                   -- book, journal, dissertation
            end
        end
    end

    OCinSoutput.rft_id = data.URL;
    OCinSoutput.rfr_id = table.concat{ "info:sid/", "Wikipedia", ":", data.RawPage };
    OCinSoutput = setmetatable( OCinSoutput, nil );
    
    -- sort with version string always first, and combine.
    table.sort( OCinSoutput );
    table.insert( OCinSoutput, 1, "ctx_ver=" .. ctx_ver );  -- such as "Z39.88-2004"
    return table.concat(OCinSoutput, "&");
end


--[[--------------------------< G E T _ I S O 6 3 9 _ C O D E >------------------------------------------------

Validates language names provided in |language= parameter if not an ISO639-1 code.  Handles the special case that is Norwegian where
ISO639-1 code 'no' is mapped to language name 'Norwegian Bokmål' by Extention:CLDR.

Returns the language name and associated ISO639-1 code.  Because case of the source may be incorrect or different from the case that Wikimedia
uses, the name comparisons are done in lower case and when a match is found, the Wikimedia version (assumed to be correct) is returned along
with the code.  When there is no match, we return the original language name string.

export_language_fetchLanguageNames() will return a list of languages that aren't part of ISO639-1. Names that aren't ISO639-1 but that are included
in the list will be found if that name is provided in the |language= parameter.  For example, if |language=Samaritan Aramaic, that name will be
found with the associated code 'sam', not an ISO639-1 code.  When names are found and the associated code is not two characters, this function
returns only the Wikimedia language name.

Adapted from code taken from Module:Check ISO 639-1.

]]

local function get_iso639_code (lang)
    -- //// CODE DELETED ////

    return lang;                                                                -- not valid language; return language in original case and nil for ISO639-1 code
end

--[[--------------------------< S E T _ C S 1 _ S T Y L E >----------------------------------------------------

Set style settings for CS1 citation templates. Returns separator and postscript settings

]]

local function set_cs1_style (ps)
    if not is_set (ps) then                                                     -- unless explicitely set to something
        ps = '.';                                                               -- terminate the rendered citation with a period
    end
    return '.', ps;                                                             -- separator is a full stop
end

--[[--------------------------< S E T _ C S 2 _ S T Y L E >----------------------------------------------------

Set style settings for CS2 citation templates. Returns separator, postscript, ref settings

]]

local function set_cs2_style (ps, ref)
    if not is_set (ps) then                                                     -- if |postscript= has not been set, set cs2 default
        ps = '';                                                                -- make sure it isn't nil
    end
    if not is_set (ref) then                                                    -- if |ref= is not set
        ref = "harv";                                                           -- set default |ref=harv
    end
    return ',', ps, ref;                                                        -- separator is a comma
end

--[[--------------------------< G E T _ S E T T I N G S _ F R O M _ C I T E _ C L A S S >----------------------

When |mode= is not set or when its value is invalid, use config.CitationClass and parameter values to establish
rendered style.

]]

local function get_settings_from_cite_class (ps, ref, cite_class)
    local sep;
    if (cite_class == "citation") then                                          -- for citation templates (CS2)
        sep, ps, ref = set_cs2_style (ps, ref);
    else                                                                        -- not a citation template so CS1
        sep, ps = set_cs1_style (ps);
    end

    return sep, ps, ref                                                         -- return them all
end

--[[--------------------------< S E T _ S T Y L E >------------------------------------------------------------

Establish basic style settings to be used when rendering the citation.  Uses |mode= if set and valid or uses
config.CitationClass from the template's #invoke: to establish style.

]]

local function set_style (mode, ps, ref, cite_class)
    local sep;
    if 'cs2' == mode then                                                       -- if this template is to be rendered in CS2 (citation) style
        sep, ps, ref = set_cs2_style (ps, ref);
    elseif 'cs1' == mode then                                                   -- if this template is to be rendered in CS1 (cite xxx) style
        sep, ps = set_cs1_style (ps);
    else                                                                        -- anything but cs1 or cs2
        sep, ps, ref = get_settings_from_cite_class (ps, ref, cite_class);      -- get settings based on the template's CitationClass
    end
    if 'none' == ps:lower() then                                                -- if assigned value is 'none' then
        ps = '';                                                                -- set to empty string
    end
    
    return sep, ps, ref
end

--[=[-------------------------< I S _ P D F >------------------------------------------------------------------

Determines if a url has the file extension that is one of the pdf file extensions used by [[MediaWiki:Common.css]] when
applying the pdf icon to external links.

returns true if file extension is one of the recognized extension, else false

]=]

local function is_pdf (url)
    return url:match ('%.pdf[%?#]?') or url:match ('%.PDF[%?#]?');
end

--[[--------------------------< S T Y L E _ F O R M A T >------------------------------------------------------

Applies css style to |format=, |chapter-format=, etc.  Also emits an error message if the format parameter does
not have a matching url parameter.  If the format parameter is not set and the url contains a file extension that
is recognized as a pdf document by MediaWiki's commons.css, this code will set the format parameter to (PDF) with
the appropriate styling.

]]

local function style_format (format, url, fmt_param, url_param)
    if is_set (format) then
        format = wrap_style ('format', format);                                 -- add leading space, parenthases, resize
        if not is_set (url) then
            format = format .. set_error( 'format_missing_url', {fmt_param, url_param} );   -- add an error message
        end
    elseif is_pdf (url) then                                                    -- format is not set so if url is a pdf file then
        format = wrap_style ('format', 'PDF');                                  -- set format to pdf
    else
        format = '';                                                            -- empty string for concatenation
    end
    return format;
end

--[[--------------------------< G E T _ D I S P L A Y _ A U T H O R S _ E D I T O R S >------------------------

Returns a number that may or may not limit the length of the author or editor name lists.

When the value assigned to |display-authors= is a number greater than or equal to zero, return the number and
the previous state of the 'etal' flag (false by default but may have been set to true if the name list contains
some variant of the text 'et al.').

When the value assigned to |display-authors= is the keyword 'etal', return a number that is one greater than the
number of authors in the list and set the 'etal' flag true.  This will cause the list_people() to display all of
the names in the name list followed by 'et al.'

In all other cases, returns nil and the previous state of the 'etal' flag.

]]

local function get_display_authors_editors (max, count, list_name, etal)
    if is_set (max) then
        if 'etal' == max:lower():gsub("[ '%.]", '') then                        -- the :gsub() portion makes 'etal' from a variety of 'et al.' spellings and stylings
            max = count + 1;                                                    -- number of authors + 1 so display all author name plus et al.
            etal = true;                                                        -- overrides value set by extract_names()
        elseif max:match ('^%d+$') then                                         -- if is a string of numbers
            max = tonumber (max);                                               -- make it a number
            if max >= count and 'authors' == list_name then -- AUTHORS ONLY     -- if |display-xxxxors= value greater than or equal to number of authors/editors
                add_maint_cat ('disp_auth_ed', list_name);
            end
        else                                                                    -- not a valid keyword or number
            table.insert( z.message_tail, { set_error( 'invalid_param_val', {'display-' .. list_name, max}, true ) } );     -- add error message
            max = nil;                                                          -- unset
        end
    elseif 'authors' == list_name then      -- AUTHORS ONLY need to clear implicit et al category
        max = count + 1;                                                        -- number of authors + 1
    end
    
    return max, etal;
end

--[[--------------------------< E X T R A _ T E X T _ I N _ P A G E _ C H E C K >------------------------------

Adds page to Category:CS1 maint: extra text if |page= or |pages= has what appears to be some form of p. or pp. 
abbreviation in the first characters of the parameter content.

check Page and Pages for extraneous p, p., pp, and pp. at start of parameter value:
    good pattern: '^P[^%.P%l]' matches when |page(s)= begins PX or P# but not Px where x and X are letters and # is a dgiit
    bad pattern: '^[Pp][Pp]' matches matches when |page(s)= begins pp or pP or Pp or PP

]]

local function extra_text_in_page_check (page)
--  local good_pattern = '^P[^%.P%l]';
    local good_pattern = '^P[^%.Pp]';                                           -- ok to begin with uppercase P: P7 (pg 7 of section P) but not p123 (page 123) TODO: add Gg for PG or Pg?
--  local bad_pattern = '^[Pp][Pp]';
    local bad_pattern = '^[Pp]?[Pp]%.?[ %d]';

    if not page:match (good_pattern) and (page:match (bad_pattern) or  page:match ('^[Pp]ages?')) then
        add_maint_cat ('extra_text');
    end
--      if Page:match ('^[Pp]?[Pp]%.?[ %d]') or  Page:match ('^[Pp]ages?[ %d]') or
--          Pages:match ('^[Pp]?[Pp]%.?[ %d]') or  Pages:match ('^[Pp]ages?[ %d]') then
--              add_maint_cat ('extra_text');
--      end
end


--[[--------------------------< P A R S E _ V A U T H O R S _ V E D I T O R S >--------------------------------

This function extracts author / editor names from |vauthors= or |veditors= and finds matching |xxxxor-maskn= and
|xxxxor-linkn= in args.  It then returns a table of assembled names just as extract_names() does.

Author / editor names in |vauthors= or |veditors= must be in Vancouver system style. Corporate or institutional names
may sometimes be required and because such names will often fail the is_good_vanc_name() and other format compliance
tests, are wrapped in doubled paranethese ((corporate name)) to suppress the format tests.

This function sets the vancouver error when a reqired comma is missing and when there is a space between an author's initials.

]]

local function parse_vauthors_veditors (args, vparam, list_name)
    local names = {};                                                           -- table of names assembled from |vauthors=, |author-maskn=, |author-linkn=
    local v_name_table = {};
    local etal = false;                                                         -- return value set to true when we find some form of et al. vauthors parameter
    local last, first, link, mask;
    local corporate = false;

    vparam, etal = name_has_etal (vparam, etal, true);                          -- find and remove variations on et al. do not categorize (do it here because et al. might have a period)
    if vparam:find ('%[%[') or vparam:find ('%]%]') then                        -- no wikilinking vauthors names
        add_vanc_error ();
    end
    v_name_table = export_text_split(vparam, "%s*,%s*")                             -- names are separated by commas

    for i, v_name in ipairs(v_name_table) do
        if v_name:match ('^%(%(.+%)%)$') then                                   -- corporate authors are wrapped in doubled parenthese to supress vanc formatting and error detection
            first = '';                                                         -- set to empty string for concatenation and because it may have been set for previous author/editor
            last = v_name:match ('^%(%((.+)%)%)$')
            corporate = true;
        elseif string.find(v_name, "%s") then
            lastfirstTable = {}
            lastfirstTable = export_text_split(v_name, "%s")
            first = table.remove(lastfirstTable);                               -- removes and returns value of last element in table which should be author intials
            last  = table.concat(lastfirstTable, " ")                           -- returns a string that is the concatenation of all other names that are not initials
            if export_ustring_match (last, '%a+%s+%u+%s+%a+') or export_ustring_match (v_name, ' %u %u$') then
                add_vanc_error ();                                              -- matches last II last; the case when a comma is missing or a space between two intiials
            end
        else
            first = '';                                                         -- set to empty string for concatenation and because it may have been set for previous author/editor
            last = v_name;                                                      -- last name or single corporate name?  Doesn't support multiword corporate names? do we need this?
        end
                                                                
        if is_set (first) and not export_ustring_match (first, "^%u?%u$") then      -- first shall contain one or two upper-case letters, nothing else
            add_vanc_error ();
        end
                                                                                -- this from extract_names ()
        link = select_one( args, cfg.aliases[list_name .. '-Link'], 'redundant_parameters', i );
        mask = select_one( args, cfg.aliases[list_name .. '-Mask'], 'redundant_parameters', i );
        names[i] = {last = last, first = first, link = link, mask = mask, corporate=corporate};     -- add this assembled name to our names list
    end
    return names, etal;                                                         -- all done, return our list of names
end

--[[--------------------------< S E L E C T _ A U T H O R _ E D I T O R _ S O U R C E >------------------------

Select one of |authors=, |authorn= / |lastn / firstn=, or |vauthors= as the source of the author name list or
select one of |editors=, |editorn= / editor-lastn= / |editor-firstn= or |veditors= as the source of the editor name list.

Only one of these appropriate three will be used.  The hierarchy is: |authorn= (and aliases) highest and |authors= lowest and
similarly, |editorn= (and aliases) highest and |editors= lowest

When looking for |authorn= / |editorn= parameters, test |xxxxor1= and |xxxxor2= (and all of their aliases); stops after the second
test which mimicks the test used in extract_names() when looking for a hole in the author name list.  There may be a better
way to do this, I just haven't discovered what that way is.

Emits an error message when more than one xxxxor name source is provided.

In this function, vxxxxors = vauthors or veditors; xxxxors = authors or editors as appropriate.

]]

local function select_author_editor_source (vxxxxors, xxxxors, args, list_name)
local lastfirst = false;
    if select_one( args, cfg.aliases[list_name .. '-Last'], 'none', 1 ) or      -- do this twice incase we have a first 1 without a last1
        select_one( args, cfg.aliases[list_name .. '-Last'], 'none', 2 ) then
            lastfirst=true;
    end

    if (is_set (vxxxxors) and true == lastfirst) or                             -- these are the three error conditions
        (is_set (vxxxxors) and is_set (xxxxors)) or
        (true == lastfirst and is_set (xxxxors)) then
            local err_name;
            if 'AuthorList' == list_name then                                   -- figure out which name should be used in error message
                err_name = 'author';
            else
                err_name = 'editor';
            end
            table.insert( z.message_tail, { set_error( 'redundant_parameters',
                {err_name .. '-name-list parameters'}, true ) } );              -- add error message
    end

    if true == lastfirst then return 1 end;                                     -- return a number indicating which author name source to use
    if is_set (vxxxxors) then return 2 end;
    if is_set (xxxxors) then return 3 end;
    return 1;                                                                   -- no authors so return 1; this allows missing author name test to run in case there is a first without last 
end


--[[--------------------------< I S _ V A L I D _ P A R A M E T E R _ V A L U E >------------------------------

This function is used to validate a parameter's assigned value for those parameters that have only a limited number
of allowable values (yes, y, true, no, etc).  When the parameter value has not been assigned a value (missing or empty
in the source template) the function refurns true.  If the parameter value is one of the list of allowed values returns
true; else, emits an error message and returns false.

]]

local function is_valid_parameter_value (value, name, possible)
    if not is_set (value) then
        return true;                                                            -- an empty parameter is ok
    elseif in_array(value:lower(), possible) then
        return true;
    else
        table.insert( z.message_tail, { set_error( 'invalid_param_val', {name, value}, true ) } );  -- not an allowed value so add error message
        return false
    end
end


--[[--------------------------< T E R M I N A T E _ N A M E _ L I S T >----------------------------------------

This function terminates a name list (author, contributor, editor) with a separator character (sepc) and a space
when the last character is not a sepc character or when the last three characters are not sepc followed by two
closing square brackets (close of a wikilink).  When either of these is true, the name_list is terminated with a
single space character.

]]

local function terminate_name_list (name_list, sepc)
    if (string.sub (name_list,-1,-1) == sepc) or (string.sub (name_list,-3,-1) == sepc .. ']]') then    -- if last name in list ends with sepc char
        return name_list .. " ";                                                -- don't add another
    else
        return name_list .. sepc .. ' ';                                        -- otherwise terninate the name list
    end
end


--[[-------------------------< F O R M A T _ V O L U M E _ I S S U E >----------------------------------------

returns the concatenation of the formatted volume and issue parameters as a single string; or formatted volume
or formatted issue, or an empty string if neither are set.

]]
    
local function format_volume_issue (volume, issue, cite_class, origin, sepc, lower)
    if not is_set (volume) and not is_set (issue) then
        return '';
    end
    
    if 'magazine' == cite_class or (in_array (cite_class, {'citation', 'map'}) and 'magazine' == origin) then
        if is_set (volume) and is_set (issue) then
            return wrap_msg ('vol-no', {sepc, volume, issue}, lower);
        elseif is_set (volume) then
            return wrap_msg ('vol', {sepc, volume}, lower);
        else
            return wrap_msg ('issue', {sepc, issue}, lower);
        end
    end
    
    local vol = '';
        
    if is_set (volume) then
        if (4 < export_ustring_len(volume)) then
            vol = substitute (cfg.messages['j-vol'], {sepc, volume});
        else
            vol = wrap_style ('vol-bold', hyphen_to_dash(volume));
        end
    end
    if is_set (issue) then
        return vol .. substitute (cfg.messages['j-issue'], issue);
    end
    return vol;
end


--[[-------------------------< F O R M A T _ P A G E S _ S H E E T S >-----------------------------------------

adds static text to one of |page(s)= or |sheet(s)= values and returns it with all of the others set to empty strings.
The return order is:
    page, pages, sheet, sheets

Singular has priority over plural when both are provided.

]]

local function format_pages_sheets (page, pages, sheet, sheets, cite_class, origin, sepc, nopp, lower)
    if 'map' == cite_class then                                                 -- only cite map supports sheet(s) as in-source locators
        if is_set (sheet) then
            if 'journal' == origin then
                return '', '', wrap_msg ('j-sheet', sheet, lower), '';
            else
                return '', '', wrap_msg ('sheet', {sepc, sheet}, lower), '';
            end
        elseif is_set (sheets) then
            if 'journal' == origin then
                return '', '', '', wrap_msg ('j-sheets', sheets, lower);
            else
                return '', '', '', wrap_msg ('sheets', {sepc, sheets}, lower);
            end
        end
    end

    local is_journal = 'journal' == cite_class or (in_array (cite_class, {'citation', 'map'}) and 'journal' == origin);

    if is_set (page) then
        if is_journal then
            return substitute (cfg.messages['j-page(s)'], page), '', '', '';
        elseif not nopp then
            return substitute (cfg.messages['p-prefix'], {sepc, page}), '', '', '';
        else
            return substitute (cfg.messages['nopp'], {sepc, page}), '', '', '';
        end
    elseif is_set(pages) then
        if is_journal then
            return substitute (cfg.messages['j-page(s)'], pages), '', '', '';
        elseif tonumber(pages) ~= nil and not nopp then                                     -- if pages is only digits, assume a single page number
            return '', substitute (cfg.messages['p-prefix'], {sepc, pages}), '', '';
        elseif not nopp then
            return '', substitute (cfg.messages['pp-prefix'], {sepc, pages}), '', '';
        else
            return '', substitute (cfg.messages['nopp'], {sepc, pages}), '', '';
        end
    end
    
    return '', '', '', '';                                                      -- return empty strings
end

--[[--------------------------< C I T A T I O N 0 >------------------------------------------------------------

This is the main function doing the majority of the citation formatting.

]]

local function get_sorted_keys(args)
    local keyset={}
    local n=0
    for k,_ in pairs(args) do
        table.insert(keyset, k)
    end
    table.sort(keyset)
    return keyset
end

local function citation0( config, args)
    --[[ 
    Load Input Parameters
    The argument_wrapper facilitates the mapping of multiple aliases to single internal variable.
    ]]

    -- This is for the new template
    local exception_citation_tmpl = {'harvnb', 'brackets'}
    local maps_citation_tmpl = {'gnis', 'geonet3'}
    local heritage_england_citation_tmpl = {'nhle', 'england'}

    if in_array(config.CitationClass, exception_citation_tmpl) then
        local keyset = get_sorted_keys(args)
        for i,k in ipairs(keyset) do
            if tonumber(k) ~= nil then
                v = args[k]
                -- Checks if the year is a number or alphanumeric since the format can be 2007 or 2007a
                if (tonumber(v) ~= nil) or (string.find(v, "%d") and true or false) then
                    args["year"] = args[k]
                    args[k] = nil
                elseif type(v) == 'string' then
                    args["last" .. k] = args[k]
                    args[k] = nil
                end
            end
        end
    end

    -- This is for chaning the version section of nrisref citation template to series and change other names
    if 'nrisref' == config.CitationClass then
        local keyset = get_sorted_keys(args)
        for i,k in ipairs(keyset) do
            if k == 'name' then
                args["title"] = args[k]
                args[k] = nil
            end
            if k == 'refnum' then
                args["seriesno"] = args[k]
                args[k] = nil
            end
            if tonumber(k) ~= nil or k == 'version' then
                if (string.find(args[k], "%d") and true or false) then
                    args["series"] = args[k]
                    args[k] = nil
                end
            end
        end
    end

    if in_array(config.CitationClass, maps_citation_tmpl) then
        local keyset = get_sorted_keys(args)
        for i,k in ipairs(keyset) do
            if tonumber(k) ~= nil then
                v = args[k]
                if (tonumber(v) ~= nil) then
                    args['seriesno'] = args[k]
                    args[k] = nil
                else
                    date_or_not,_ = check_date(args[k], nil)
                    if date_or_not then
                        args["accessdate"] = args[k]
                        args[k] = nil
                    else
                        args["title"] = args[k]
                        args[k] = nil
                    end
                end
            else
                if k == 'id' then
                    args['seriesno'] = args[k]
                    args[k] = nil
                end
                if k == 'name' then
                    args["title"] = args[k]
                    args[k] = nil
                end
            end
        end
    end

    if config.CitationClass == 'season' then
        local keyset = get_sorted_keys(args)
        for i,k in ipairs(keyset) do
            if tonumber(k) ~= nil  then
                v = args[k]
                date_or_not,_ = check_date(args[k], nil)
                if date_or_not then
                    args["year"] = args[k]
                    args[k] = nil
                else
                    args["seriesno"] = args[k]
                    args[k] = nil
                end
            else
                if k == 'id' then
                    args['seriesno'] = args[k]
                    args[k] = nil
                end
                if k == 'name' then
                    args["title"] = args[k]
                    args[k] = nil
                end
                if k == 'season' then
                    args["year"] = args[k]
                    args[k] = nil
                end
            end
        end
    end

    if config.CitationClass == 'sports-reference' then
        local keyset = get_sorted_keys(args)
        for i,k in ipairs(keyset) do
            if k == '1' then
                args['title'] = args[k]
                args[k] = nil
            end
            if k == '2' then
                args["url"] = args[k]
                args[k] = nil
            end
            if k == '3' then
                args["accessdate"] = args[k]
                args[k] = nil
            end
        end
    end

    if in_array(config.CitationClass, heritage_england_citation_tmpl) then
        local keyset = get_sorted_keys(args)
        for i,k in ipairs(keyset) do
            if tonumber(k) ~= nil then
                args['seriesno'] = args[k]
                args[k] = nil
            else
                if k == 'num' then
                    args['seriesno'] = args[k]
                    args[k] = nil
                end
                if k == 'desc' then
                    args["title"] = args[k]
                    args[k] = nil
                end
            end
        end
    end

    local A = argument_wrapper( args );
    local i

    -- Pick out the relevant fields from the arguments.  Different citation templates
    -- define different field names for the same underlying things. 
    local author_etal;
    local a = {};                                                               -- authors list from |lastn= / |firstn= pairs or |vauthors=
    local Authors;
    local NameListFormat = A['NameListFormat'];

    do                                                                          -- to limit scope of selected
        local selected = select_author_editor_source (A['Vauthors'], A['Authors'], args, 'AuthorList');
        if 1 == selected then
            a, author_etal = extract_names (args, 'AuthorList');                -- fetch author list from |authorn= / |lastn= / |firstn=, |author-linkn=, and |author-maskn=
        elseif 2 == selected then
            NameListFormat = 'vanc';                                            -- override whatever |name-list-format= might be
            a, author_etal = parse_vauthors_veditors (args, args.vauthors, 'AuthorList');   -- fetch author list from |vauthors=, |author-linkn=, and |author-maskn=
        elseif 3 == selected then
            Authors = A['Authors'];                                             -- use content of |authors=
        end
    end

    local Coauthors = A['Coauthors'];
    local Others = A['Others'];

    local editor_etal;
    local e = {};                                                               -- editors list from |editor-lastn= / |editor-firstn= pairs or |veditors=
    local Editors;

    do                                                                          -- to limit scope of selected
        local selected = select_author_editor_source (A['Veditors'], A['Editors'], args, 'EditorList');
        if 1 == selected then
            e, editor_etal = extract_names (args, 'EditorList');                -- fetch editor list from |editorn= / |editor-lastn= / |editor-firstn=, |editor-linkn=, and |editor-maskn=
        elseif 2 == selected then
            NameListFormat = 'vanc';                                            -- override whatever |name-list-format= might be
            e, editor_etal = parse_vauthors_veditors (args, args.veditors, 'EditorList');   -- fetch editor list from |veditors=, |editor-linkn=, and |editor-maskn=
        elseif 3 == selected then
            Editors = A['Editors'];                                             -- use content of |editors=
        end
    end

    local t = {};                                                               -- translators list from |translator-lastn= / translator-firstn= pairs
    local Translators;                                                          -- assembled translators name list
    t = extract_names (args, 'TranslatorList');                                 -- fetch translator list from |translatorn= / |translator-lastn=, -firstn=, -linkn=, -maskn=
    
    local c = {};                                                               -- contributors list from |contributor-lastn= / contributor-firstn= pairs
    local Contributors;                                                         -- assembled contributors name list
    local Contribution = A['Contribution'];
    if in_array(config.CitationClass, {"book","citation"}) and not is_set(A['Periodical']) then -- |contributor= and |contribution= only supported in book cites
        c = extract_names (args, 'ContributorList');                            -- fetch contributor list from |contributorn= / |contributor-lastn=, -firstn=, -linkn=, -maskn=
        
        if 0 < #c then
            if not is_set (Contribution) then                                   -- |contributor= requires |contribution=
                table.insert( z.message_tail, { set_error( 'contributor_missing_required_param', 'contribution')}); -- add missing contribution error message
                c = {};                                                         -- blank the contributors' table; it is used as a flag later
            end
            if 0 == #a then                                                     -- |contributor= requires |author=
                table.insert( z.message_tail, { set_error( 'contributor_missing_required_param', 'author')});   -- add missing author error message
                c = {};                                                         -- blank the contributors' table; it is used as a flag later
            end
        end
    else                                                                        -- if not a book cite
        if select_one (args, cfg.aliases['ContributorList-Last'], 'redundant_parameters', 1 ) then  -- are there contributor name list parameters?
            table.insert( z.message_tail, { set_error( 'contributor_ignored')});    -- add contributor ignored error message
        end
        Contribution = nil;                                                     -- unset
    end

    if not is_valid_parameter_value (NameListFormat, 'name-list-format', cfg.keywords['name-list-format']) then         -- only accepted value for this parameter is 'vanc'
        NameListFormat = '';                                                    -- anything else, set to empty string
    end

    local Year = A['Year'];
    local PublicationDate = A['PublicationDate'];
    local OrigYear = A['OrigYear'];
    local Date = A['Date'];
    local LayDate = A['LayDate'];
    ------------------------------------------------- Get title data
    local Title = A['Title'];
    local ScriptTitle = A['ScriptTitle'];
    local BookTitle = A['BookTitle'];
    local Conference = A['Conference'];
    local TransTitle = A['TransTitle'];
    local TitleNote = A['TitleNote'];
    local TitleLink = A['TitleLink'];
        if is_set (TitleLink) and false == link_param_ok (TitleLink) then
            table.insert( z.message_tail, { set_error( 'bad_paramlink', A:ORIGIN('TitleLink'))});       -- url or wikilink in |title-link=;
        end

    local Chapter = A['Chapter'];
    local ScriptChapter = A['ScriptChapter'];
    local ChapterLink   -- = A['ChapterLink'];                                  -- deprecated as a parameter but still used internally by cite episode
    local TransChapter = A['TransChapter'];
    local TitleType = A['TitleType'];
    local Degree = A['Degree'];
    local Docket = A['Docket'];
    local ArchiveFormat = A['ArchiveFormat'];
    local ArchiveURL = A['ArchiveURL'];
    local URL = A['URL']
    local URLorigin = A:ORIGIN('URL');                                          -- get name of parameter that holds URL
    local ChapterURL = A['ChapterURL'];
    local ChapterURLorigin = A:ORIGIN('ChapterURL');                            -- get name of parameter that holds ChapterURL
    local ConferenceFormat = A['ConferenceFormat'];
    local ConferenceURL = A['ConferenceURL'];
    local ConferenceURLorigin = A:ORIGIN('ConferenceURL');                      -- get name of parameter that holds ConferenceURL
    local Periodical = A['Periodical'];
    local Periodical_origin = A:ORIGIN('Periodical');                           -- get the name of the periodical parameter
    local Series = A['Series'];
    
    local City;                                                                 -- Added the City for London Gazette citation
    local Volume;
    local Issue;
    local Page;
    local Pages;
    local At;

    if in_array (config.CitationClass, cfg.templates_using_volume) and not ('conference' == config.CitationClass and not is_set (Periodical)) then
        Volume = A['Volume'];
    end

    if in_array (config.CitationClass, cfg.templates_using_issue) and not (in_array (config.CitationClass, {'conference', 'map'}) and not is_set (Periodical))then
        Issue = A['Issue'];
    end
    local Position = '';
    if not in_array (config.CitationClass, cfg.templates_not_using_page) then
        Page = A['Page'];
        Pages = hyphen_to_dash( A['Pages'] );   
        At = A['At'];
    end

    local Edition = A['Edition'];
    local PublicationPlace = A['PublicationPlace']
    local Place = A['Place'];
    
    local PublisherName = A['PublisherName'];
    local RegistrationRequired = A['RegistrationRequired'];
        if not is_valid_parameter_value (RegistrationRequired, 'registration', cfg.keywords ['yes_true_y']) then
            RegistrationRequired=nil;
        end
    local SubscriptionRequired = A['SubscriptionRequired'];
        if not is_valid_parameter_value (SubscriptionRequired, 'subscription', cfg.keywords ['yes_true_y']) then
            SubscriptionRequired=nil;
        end

    local Via = A['Via'];

    local AccessDate;
    -- This is just for templates which want to have accessdate
    if in_array(config.CitationClass, templates_using_accessdate) then
        AccessDate = A['AccessDate']
    end

    local ArchiveDate = A['ArchiveDate'];
    local Agency = A['Agency'];
    local DeadURL = A['DeadURL']
        if not is_valid_parameter_value (DeadURL, 'dead-url', cfg.keywords ['deadurl']) then    -- set in config.defaults to 'yes'
            DeadURL = '';                                                       -- anything else, set to empty string
        end

    local Language = A['Language'];
    local Format = A['Format'];
    local ChapterFormat = A['ChapterFormat'];
    local DoiBroken = A['DoiBroken'];
    local ID = A['ID'];
    local ASINTLD = A['ASINTLD'];
    local IgnoreISBN = A['IgnoreISBN'];
        if not is_valid_parameter_value (IgnoreISBN, 'ignore-isbn-error', cfg.keywords ['yes_true_y']) then
            IgnoreISBN = nil;                                                   -- anything else, set to empty string
        end
    local Embargo = A['Embargo'];
    local Class = A['Class'];                                                   -- arxiv class identifier

    local ID_list = extract_ids( args );

    local Quote = A['Quote'];

    local LayFormat = A['LayFormat'];
    local LayURL = A['LayURL'];
    local LaySource = A['LaySource'];
    local Transcript = A['Transcript'];
    local TranscriptFormat = A['TranscriptFormat'];
    local TranscriptURL = A['TranscriptURL'] 
    local TranscriptURLorigin = A:ORIGIN('TranscriptURL');                      -- get name of parameter that holds TranscriptURL

    local LastAuthorAmp = A['LastAuthorAmp'];
        if not is_valid_parameter_value (LastAuthorAmp, 'last-author-amp', cfg.keywords ['yes_true_y']) then
            LastAuthorAmp = nil;                                                    -- set to empty string
        end
    local no_tracking_cats = A['NoTracking'];
        if not is_valid_parameter_value (no_tracking_cats, 'no-tracking', cfg.keywords ['yes_true_y']) then
            no_tracking_cats = nil;                                             -- set to empty string
        end

--these are used by cite interview
    local Callsign = A['Callsign'];
    local City = A['City'];
    local Program = A['Program'];

--local variables that are not cs1 parameters
    local use_lowercase;                                                        -- controls capitalization of certain static text
    local this_page = current_page_title;                               -- also used for COinS and for language
    local anchor_year;                                                          -- used in the CITEREF identifier
    local COinS_date = {};                                                      -- holds date info extracted from |date= for the COinS metadata by Module:Date verification

-- set default parameter values defined by |mode= parameter.  If |mode= is empty or omitted, use CitationClass to set these values
    local Mode = A['Mode'];
    if not is_valid_parameter_value (Mode, 'mode', cfg.keywords['mode']) then
        Mode = '';
    end
    local sepc;                                         -- separator between citation elements for CS1 a period, for CS2, a comma
    local PostScript;
    local Ref;
    sepc, PostScript, Ref = set_style (Mode:lower(), A['PostScript'], A['Ref'], config.CitationClass);
    use_lowercase = ( sepc == ',' );                    -- used to control capitalization for certain static text

--check this page to see if it is in one of the namespaces that cs1 is not supposed to add to the error categories
    if not is_set (no_tracking_cats) then                                       -- ignore if we are already not going to categorize this page
        if in_array (this_page.nsText, cfg.uncategorized_namespaces) then
            no_tracking_cats = "true";                                          -- set no_tracking_cats
        end
    end

-- check for extra |page=, |pages= or |at= parameters. (also sheet and sheets while we're at it)
    select_one( args, {'page', 'p', 'pp', 'pages', 'at', 'sheet', 'sheets'}, 'redundant_parameters' );      -- this is a dummy call simply to get the error message and category

    local NoPP = A['NoPP'] 
    if is_set (NoPP) and is_valid_parameter_value (NoPP, 'nopp', cfg.keywords ['yes_true_y']) then
        NoPP = true;
    else
        NoPP = nil;                                                             -- unset, used as a flag later
    end

    if is_set(Page) then
        if is_set(Pages) or is_set(At) then
            Pages = '';                                                         -- unset the others
            At = '';
        end
        extra_text_in_page_check (Page);                                        -- add this page to maint cat if |page= value begins with what looks like p. or pp.
    elseif is_set(Pages) then
        if is_set(At) then
            At = '';                                                            -- unset
        end
        extra_text_in_page_check (Pages);                                       -- add this page to maint cat if |pages= value begins with what looks like p. or pp.
    end 

-- both |publication-place= and |place= (|location=) allowed if different
    if not is_set(PublicationPlace) and is_set(Place) then
        PublicationPlace = Place;                           -- promote |place= (|location=) to |publication-place
    end
    
    if PublicationPlace == Place then Place = ''; end       -- don't need both if they are the same
    
--[[
Parameter remapping for cite encyclopedia:
When the citation has these parameters:
    |encyclopedia and |title then map |title to |article and |encyclopedia to |title
    |encyclopedia and |article then map |encyclopedia to |title
    |encyclopedia then map |encyclopedia to |title

    |trans_title maps to |trans_chapter when |title is re-mapped
    |url maps to |chapterurl when |title is remapped

All other combinations of |encyclopedia, |title, and |article are not modified

]]


local Encyclopedia = A['Encyclopedia'];

    if ( config.CitationClass == "encyclopaedia" ) or ( config.CitationClass == "citation" and is_set (Encyclopedia)) then  -- test code for citation
        if is_set(Periodical) then                                              -- Periodical is set when |encyclopedia is set
            if is_set(Title) or is_set (ScriptTitle) then
                if not is_set(Chapter) then
                    Chapter = Title;                                            -- |encyclopedia and |title are set so map |title to |article and |encyclopedia to |title
                    ScriptChapter = ScriptTitle;
                    TransChapter = TransTitle;
                    ChapterURL = URL;
                    if not is_set (ChapterURL) and is_set (TitleLink) then
                        Chapter= '[[' .. TitleLink .. '|' .. Chapter .. ']]';
                    end
                    Title = Periodical;
                    ChapterFormat = Format;
                    Periodical = '';                                            -- redundant so unset
                    TransTitle = '';
                    URL = '';
                    Format = '';
                    TitleLink = '';
                    ScriptTitle = '';
                end
            else                                                                -- |title not set
                Title = Periodical;                                             -- |encyclopedia set and |article set or not set so map |encyclopedia to |title
                Periodical = '';                                                -- redundant so unset
            end
        end
    end

-- Special case for cite techreport.
    if (config.CitationClass == "techreport") then                              -- special case for cite techreport
        if is_set(A['Number']) then                                                 -- cite techreport uses 'number', which other citations alias to 'issue'
            if not is_set(ID) then                                              -- can we use ID for the "number"?
                ID = A['Number'];                                                   -- yes, use it
            else                                                                -- ID has a value so emit error message
                table.insert( z.message_tail, { set_error('redundant_parameters', {wrap_style ('parameter', 'id') .. ' and ' .. wrap_style ('parameter', 'number')}, true )});
            end
        end 
    end

-- special case for cite interview
    if (config.CitationClass == "interview") then
        if is_set(Program) then
            ID = ' ' .. Program;
        end
        if is_set(Callsign) then
            if is_set(ID) then
                ID = ID .. sepc .. ' ' .. Callsign;
            else
                ID = ' ' .. Callsign;
            end
        end
        if is_set(City) then
            if is_set(ID) then
                ID = ID .. sepc .. ' ' .. City;
            else
                ID = ' ' .. City;
            end
        end

        if is_set(Others) then
            if is_set(TitleType) then
                Others = ' ' .. TitleType .. ' with ' .. Others;
                TitleType = '';
            else
                Others = ' ' .. 'Interview with ' .. Others;
            end
        else
            Others = '(Interview)';
        end
    end

-- special case for cite mailing list
    if (config.CitationClass == "mailinglist") then
        Periodical = A ['MailingList'];
    elseif 'mailinglist' == A:ORIGIN('Periodical') then
        Periodical = '';                                                        -- unset because mailing list is only used for cite mailing list
    end

-- Account for the oddity that is {{cite conference}}, before generation of COinS data.
    if 'conference' == config.CitationClass then
        if is_set(BookTitle) then
            Chapter = Title;
--          ChapterLink = TitleLink;                                            -- |chapterlink= is deprecated
            ChapterURL = URL;
            ChapterURLorigin = URLorigin;
            URLorigin = '';
            ChapterFormat = Format;
            TransChapter = TransTitle;
            Title = BookTitle;
            Format = '';
--          TitleLink = '';
            TransTitle = '';
            URL = '';
        end
    elseif 'speech' ~= config.CitationClass then
        Conference = '';                                                        -- not cite conference or cite speech so make sure this is empty string
    end

-- cite map oddities
    local Cartography = "";
    local Scale = "";
    local Sheet = A['Sheet'] or '';
    local Sheets = A['Sheets'] or '';
    if config.CitationClass == "map" then
        Chapter = A['Map'];
        ChapterURL = A['MapURL'];
        TransChapter = A['TransMap'];
        ChapterURLorigin = A:ORIGIN('MapURL');
        ChapterFormat = A['MapFormat'];
        
        Cartography = A['Cartography'];
        if is_set( Cartography ) then
            Cartography = sepc .. " " .. wrap_msg ('cartography', Cartography, use_lowercase);
        end     
        Scale = A['Scale'];
        if is_set( Scale ) then
            Scale = sepc .. " " .. Scale;
        end
    end

-- Account for the oddities that are {{cite episode}} and {{cite serial}}, before generation of COinS data.
    if 'episode' == config.CitationClass or 'serial' == config.CitationClass then
        local AirDate = A['AirDate'];
        local SeriesLink = A['SeriesLink'];
            if is_set (SeriesLink) and false == link_param_ok (SeriesLink) then
                table.insert( z.message_tail, { set_error( 'bad_paramlink', A:ORIGIN('SeriesLink'))});
            end
        local Network = A['Network'];
        local Station = A['Station'];
        local s, n = {}, {};
                                                                                -- do common parameters first
        if is_set(Network) then table.insert(n, Network); end
        if is_set(Station) then table.insert(n, Station); end
        ID = table.concat(n, sepc .. ' ');
        
        if not is_set (Date) and is_set (AirDate) then                          -- promote airdate to date
            Date = AirDate;
        end

        local Season;
        if 'episode' == config.CitationClass then                               -- handle the oddities that are strictly {{cite episode}}
            Season = A['Season'];
            local SeriesNumber = A['SeriesNumber'];

            if is_set (Season) and is_set (SeriesNumber) then                   -- these are mutually exclusive so if both are set
                table.insert( z.message_tail, { set_error( 'redundant_parameters', {wrap_style ('parameter', 'season') .. ' and ' .. wrap_style ('parameter', 'seriesno')}, true ) } );     -- add error message
                SeriesNumber = '';                                              -- unset; prefer |season= over |seriesno=
            end
                                                                                -- assemble a table of parts concatenated later into Series
            if is_set(Season) then table.insert(s, wrap_msg ('season', Season, use_lowercase)); end
            if is_set(SeriesNumber) then table.insert(s, wrap_msg ('series', SeriesNumber, use_lowercase)); end
            if is_set(Issue) then table.insert(s, wrap_msg ('episode', Issue, use_lowercase)); end
            Issue = '';                                                         -- unset because this is not a unique parameter
    
            Chapter = Title;                                                    -- promote title parameters to chapter
            ScriptChapter = ScriptTitle;
            ChapterLink = TitleLink;                                            -- alias episodelink
            TransChapter = TransTitle;
            ChapterURL = URL;
            ChapterURLorigin = A:ORIGIN('URL');
            
            Title = Series;                                                     -- promote series to title
            TitleLink = SeriesLink;
            Series = table.concat(s, sepc .. ' ');                              -- this is concatenation of season, seriesno, episode number

            if is_set (ChapterLink) and not is_set (ChapterURL) then            -- link but not URL
                Chapter = '[[' .. ChapterLink .. '|' .. Chapter .. ']]';        -- ok to wikilink
            elseif is_set (ChapterLink) and is_set (ChapterURL) then            -- if both are set, URL links episode;
                Series = '[[' .. ChapterLink .. '|' .. Series .. ']]';          -- series links with ChapterLink (episodelink -> TitleLink -> ChapterLink) ugly
            end
            URL = '';                                                           -- unset
            TransTitle = '';
            ScriptTitle = '';
            
        else                                                                    -- now oddities that are cite serial
            Issue = '';                                                         -- unset because this parameter no longer supported by the citation/core version of cite serial
            Chapter = A['Episode'];                                             -- TODO: make |episode= available to cite episode someday?
            if is_set (Series) and is_set (SeriesLink) then
                Series = '[[' .. SeriesLink .. '|' .. Series .. ']]';
            end
            Series = wrap_style ('italic-title', Series);                       -- series is italicized
        end 
    end
-- end of {{cite episode}} stuff

-- Account for the oddities that are {{cite arxiv}}, before generation of COinS data.
    if 'arxiv' == config.CitationClass then
        if not is_set (ID_list['ARXIV']) then                                   -- |arxiv= or |eprint= required for cite arxiv
            table.insert( z.message_tail, { set_error( 'arxiv_missing', {}, true ) } );     -- add error message
        elseif is_set (Series) then                                             -- series is an alias of version
            ID_list['ARXIV'] = ID_list['ARXIV'] .. Series;                      -- concatenate version onto the end of the arxiv identifier
            Series = '';                                                        -- unset
            deprecated_parameter ('version');                                   -- deprecated parameter but only for cite arxiv
        end
        
        if first_set ({AccessDate, At, Chapter, Format, Page, Pages, Periodical, PublisherName, URL,    -- a crude list of parameters that are not supported by cite arxiv
            ID_list['ASIN'], ID_list['BIBCODE'], ID_list['DOI'], ID_list['ISBN'], ID_list['ISSN'],
            ID_list['JFM'], ID_list['JSTOR'], ID_list['LCCN'], ID_list['MR'], ID_list['OCLC'], ID_list['OL'],
            ID_list['OSTI'], ID_list['PMC'], ID_list['PMID'], ID_list['RFC'], ID_list['SSRN'], ID_list['USENETID'], ID_list['ZBL']},27) then
                table.insert( z.message_tail, { set_error( 'arxiv_params_not_supported', {}, true ) } );        -- add error message

                AccessDate= '';                                                 -- set these to empty string; not supported in cite arXiv
                PublisherName = '';                                             -- (if the article has been published, use cite journal, or other)
                Chapter = '';
                URL = '';
                Format = '';
                Page = ''; Pages = ''; At = '';
        end
        Periodical = 'arXiv';                                                   -- set to arXiv for COinS; after that, must be set to empty string
    end

-- handle type parameter for those CS1 citations that have default values
    if in_array(config.CitationClass, {"AV-media-notes", "DVD-notes", "mailinglist", "map", "podcast", "pressrelease", "report", "techreport", "thesis"}) then
        TitleType = set_titletype (config.CitationClass, TitleType);
        if is_set(Degree) and "Thesis" == TitleType then                        -- special case for cite thesis
            TitleType = Degree .. " thesis";
        end
    end

    if is_set(TitleType) then                                                   -- if type parameter is specified
    TitleType = substitute( cfg.messages['type'], TitleType);                   -- display it in parentheses
    end

-- legacy: promote concatenation of |month=, and |year= to Date if Date not set; or, promote PublicationDate to Date if neither Date nor Year are set.
    if not is_set (Date) then
        Date = Year;                                                            -- promote Year to Date
        Year = nil;                                                             -- make nil so Year as empty string isn't used for CITEREF
        if not is_set (Date) and is_set(PublicationDate) then                   -- use PublicationDate when |date= and |year= are not set
            Date = PublicationDate;                                             -- promote PublicationDate to Date
            PublicationDate = '';                                               -- unset, no longer needed
        end
    end

    if PublicationDate == Date then PublicationDate = ''; end                   -- if PublicationDate is same as Date, don't display in rendered citation

--[[
Go test all of the date-holding parameters for valid MOS:DATE format and make sure that dates are real dates. This must be done before we do COinS because here is where
we get the date used in the metadata.

Date validation supporting code is in Module:Citation/CS1/Date_validation
]]
    do  -- create defined block to contain local variables error_message and mismatch
        local error_message = '';
                                                                                -- AirDate has been promoted to Date so not necessary to check it
        anchor_year, error_message = dates({['access-date']=AccessDate, ['archive-date']=ArchiveDate, ['date']=Date, ['doi-broken-date']=DoiBroken,
            ['embargo']=Embargo, ['lay-date']=LayDate, ['publication-date']=PublicationDate, ['year']=Year}, COinS_date);

        if is_set (Year) and is_set (Date) then                                 -- both |date= and |year= not normally needed; 
            local mismatch = year_date_check (Year, Date)
            if 0 == mismatch then                                               -- |year= does not match a year-value in |date=
                if is_set (error_message) then                                  -- if there is already an error message
                    error_message = error_message .. ', ';                      -- tack on this additional message
                end
                error_message = error_message .. '&#124;year= / &#124;date= mismatch';
            elseif 1 == mismatch then                                           -- |year= matches year-value in |date=
                add_maint_cat ('date_year');
            end
        end

        if is_set(error_message) then
            table.insert( z.message_tail, { set_error( 'bad_date', {error_message}, true ) } ); -- add this error message
        end
    end -- end of do

-- Account for the oddity that is {{cite journal}} with |pmc= set and |url= not set.  Do this after date check but before COInS.
-- Here we unset Embargo if PMC not embargoed (|embargo= not set in the citation) or if the embargo time has expired. Otherwise, holds embargo date
    Embargo = is_embargoed (Embargo);                                           -- 

    if config.CitationClass == "journal" and not is_set(URL) and is_set(ID_list['PMC']) then
        if not is_set (Embargo) then                                            -- if not embargoed or embargo has expired
            URL=cfg.id_handlers['PMC'].prefix .. ID_list['PMC'];                -- set url to be the same as the PMC external link if not embargoed
            URLorigin = cfg.id_handlers['PMC'].parameters[1];                   -- set URLorigin to parameter name for use in error message if citation is missing a |title=
        end
    end

-- At this point fields may be nil if they weren't specified in the template use.  We can use that fact.
    -- Test if citation has no title
    if  not is_set(Title) and
        not is_set(TransTitle) and
        not is_set(ScriptTitle) then
            if 'episode' == config.CitationClass then                           -- special case for cite episode; TODO: is there a better way to do this?
                table.insert( z.message_tail, { set_error( 'citation_missing_title', {'series'}, true ) } );
            else
                table.insert( z.message_tail, { set_error( 'citation_missing_title', {'title'}, true ) } );
            end
    end
    
    if 'none' == Title and in_array (config.CitationClass, {'journal', 'citation'}) and is_set (Periodical) and 'journal' == A:ORIGIN('Periodical') then    -- special case for journal cites
        Title = '';                                                             -- set title to empty string
        add_maint_cat ('untitled');
    end

    check_for_url ({                                                            -- add error message when any of these parameters contains a URL
        ['title']=Title,
        [A:ORIGIN('Chapter')]=Chapter,
        [A:ORIGIN('Periodical')]=Periodical,
        [A:ORIGIN('PublisherName')] = PublisherName,
        });

    -- COinS metadata (see <http://ocoins.info/>) for automated parsing of citation information.
    -- handle the oddity that is cite encyclopedia and {{citation |encyclopedia=something}}. Here we presume that
    -- when Periodical, Title, and Chapter are all set, then Periodical is the book (encyclopedia) title, Title
    -- is the article title, and Chapter is a section within the article.  So, we remap 
    
    local coins_chapter = Chapter;                                              -- default assuming that remapping not required
    local coins_title = Title;                                                  -- et tu
    if 'encyclopaedia' == config.CitationClass or ('citation' == config.CitationClass and is_set (Encyclopedia)) then
        if is_set (Chapter) and is_set (Title) and is_set (Periodical) then     -- if all are used then
            coins_chapter = Title;                                              -- remap
            coins_title = Periodical;
        end
    end
    local coins_author = a;                                                     -- default for coins rft.au 
    if 0 < #c then                                                              -- but if contributor list
        coins_author = c;                                                       -- use that instead
    end

    -- This is just for Gazette since the cities in Gazette represent the particular Gazette which could be linked to other cities
    if config.CitationClass == 'gazette' then
        local city_names = {['b'] = 'Belfast', ['belfast'] = 'Belfast', ['e'] = 'Edinburgh', ['edinburgh'] = 'Edinburgh'};
        City = A['City'] and A['City']:lower();                              -- lower() to index into the city_names table
        City = city_names[City] or 'London';                                  -- the city, or default to London
    end

    if in_array(config.CitationClass, templates_using_series_no_as_id) then
        SeriesNumber = A['SeriesNumber']
    end

    -- The type only exists for map types which are present in antartic and for this specific citation
    if config.CitationClass == 'gnis' then
        TitleType = A['TitleType']
    end

    -- this is the function call to COinS()
    --local OCinSoutput = COinS({
    return {
        ['Periodical'] = Periodical,
        ['Encyclopedia'] = Encyclopedia,
        ['Chapter'] = make_coins_title (coins_chapter, ScriptChapter),          -- Chapter and ScriptChapter stripped of bold / italic wikimarkup
        ['Map'] = Map,
        ['Degree'] = Degree;                                                    -- cite thesis only
        ['Title'] = make_coins_title (coins_title, ScriptTitle),                -- Title and ScriptTitle stripped of bold / italic wikimarkup
        ['PublicationPlace'] = PublicationPlace,
        ['Date'] = COinS_date.rftdate,                                          -- COinS_date has correctly formatted date if Date is valid;
        ['Season'] = Season,
        ['Chron'] =  COinS_date.rftchron or (not COinS_date.rftdate and Date) or '',    -- chron but if not set and invalid date format use Date; keep this last bit?
        ['Series'] = Series,
        ['Volume'] = Volume,
        ['City'] = City,
        ['Issue'] = Issue,
        ['Pages'] = get_coins_pages (first_set ({Sheet, Sheets, Page, Pages, At}, 5)),              -- pages stripped of external links
        ['Edition'] = Edition,
        ['PublisherName'] = PublisherName,
        ['URL'] = first_set ({ChapterURL, URL}, 2),
        ['Format'] = Format,
        ['Authors'] = coins_author,
        ['ID_list'] = ID_list,
        ['RawPage'] = this_page.prefixedText,
        ['AccessDate'] = AccessDate,
        ['SeriesNumber'] = SeriesNumber,
        ['TitleType'] = TitleType
    }; -- , config.CitationClass);

end

local function testfunc()

-- Account for the oddities that are {{cite arxiv}}, AFTER generation of COinS data.
    if 'arxiv' == config.CitationClass then                                     -- we have set rft.jtitle in COinS to arXiv, now unset so it isn't displayed
        Periodical = '';                                                        -- periodical not allowed in cite arxiv; if article has been published, use cite journal
    end

-- special case for cite newsgroup.  Do this after COinS because we are modifying Publishername to include some static text
    if 'newsgroup' == config.CitationClass then
        if is_set (PublisherName) then
            PublisherName = substitute (cfg.messages['newsgroup'], external_link( 'news:' .. PublisherName, PublisherName, A:ORIGIN('PublisherName') ));
        end
    end



    -- Now perform various field substitutions.
    -- We also add leading spaces and surrounding markup and punctuation to the
    -- various parts of the citation, but only when they are non-nil.
    local EditorCount;                                                          -- used only for choosing {ed.) or (eds.) annotation at end of editor name-list
    do
        local last_first_list;
        local maximum;
        local control = { 
            format = NameListFormat,                                            -- empty string or 'vanc'
            maximum = nil,                                                      -- as if display-authors or display-editors not set
            lastauthoramp = LastAuthorAmp,
            page_name = this_page.text                                          -- get current page name so that we don't wikilink to it via editorlinkn
        };

        do                                                                      -- do editor name list first because coauthors can modify control table
            maximum , editor_etal = get_display_authors_editors (A['DisplayEditors'], #e, 'editors', editor_etal);
            -- Preserve old-style implicit et al.
            if not is_set(maximum) and #e == 4 then 
                maximum = 3;
                table.insert( z.message_tail, { set_error('implict_etal_editor', {}, true) } );
            end

            control.maximum = maximum;
            
            last_first_list, EditorCount = list_people(control, e, editor_etal, 'editor');

            if is_set (Editors) then
                if editor_etal then
                    Editors = Editors .. ' ' .. cfg.messages['et al'];          -- add et al. to editors parameter beause |display-editors=etal
                    EditorCount = 2;                                            -- with et al., |editors= is multiple names; spoof to display (eds.) annotation
                else
                    EditorCount = 2;                                            -- we don't know but assume |editors= is multiple names; spoof to display (eds.) annotation
                end
            else
                Editors = last_first_list;                                      -- either an author name list or an empty string
            end

            if 1 == EditorCount and (true == editor_etal or 1 < #e) then        -- only one editor displayed but includes etal then 
                EditorCount = 2;                                                -- spoof to display (eds.) annotation
            end
        end
        do                                                                      -- now do translators
            control.maximum = #t;                                               -- number of translators
            Translators = list_people(control, t, false, 'translator');         -- et al not currently supported
        end
        do                                                                      -- now do contributors
            control.maximum = #c;                                               -- number of contributors
            Contributors = list_people(control, c, false, 'contributor');       -- et al not currently supported
        end
        do                                                                      -- now do authors
            control.maximum , author_etal = get_display_authors_editors (A['DisplayAuthors'], #a, 'authors', author_etal);

            if is_set(Coauthors) then                                           -- if the coauthor field is also used, prevent ampersand and et al. formatting.
                control.lastauthoramp = nil;
                control.maximum = #a + 1;
            end
            
            last_first_list = list_people(control, a, author_etal, 'author');

            if is_set (Authors) then
                Authors, author_etal = name_has_etal (Authors, author_etal, false); -- find and remove variations on et al.
                if author_etal then
                    Authors = Authors .. ' ' .. cfg.messages['et al'];          -- add et al. to authors parameter
                end
            else
                Authors = last_first_list;                                      -- either an author name list or an empty string
            end
        end                                                                     -- end of do

        if not is_set(Authors) and is_set(Coauthors) then                       -- coauthors aren't displayed if one of authors=, authorn=, or lastn= isn't specified
            table.insert( z.message_tail, { set_error('coauthors_missing_author', {}, true) } );    -- emit error message
        end
    end

-- apply |[xx-]format= styling; at the end, these parameters hold correctly styled format annotation,
-- an error message if the associated url is not set, or an empty string for concatenation
    ArchiveFormat = style_format (ArchiveFormat, ArchiveURL, 'archive-format', 'archive-url');
    ConferenceFormat = style_format (ConferenceFormat, ConferenceURL, 'conference-format', 'conference-url');
    Format = style_format (Format, URL, 'format', 'url');
    LayFormat = style_format (LayFormat, LayURL, 'lay-format', 'lay-url');
    TranscriptFormat = style_format (TranscriptFormat, TranscriptURL, 'transcript-format', 'transcripturl');

-- special case for chapter format so no error message or cat when chapter not supported
    if not (in_array(config.CitationClass, {'web','news','journal', 'magazine', 'pressrelease','podcast', 'newsgroup', 'arxiv'}) or
        ('citation' == config.CitationClass and is_set (Periodical) and not is_set (Encyclopedia))) then
            ChapterFormat = style_format (ChapterFormat, ChapterURL, 'chapter-format', 'chapter-url');
    end

    if  not is_set(URL) then --and
        if in_array(config.CitationClass, {"web","podcast", "mailinglist"}) then        -- Test if cite web or cite podcast |url= is missing or empty 
            table.insert( z.message_tail, { set_error( 'cite_web_url', {}, true ) } );
        end
        
        -- Test if accessdate is given without giving a URL
        if is_set(AccessDate) and not is_set(ChapterURL)then                    -- ChapterURL may be set when the others are not set; TODO: move this to a separate test?
            table.insert( z.message_tail, { set_error( 'accessdate_missing_url', {}, true ) } );
            AccessDate = '';
        end
    end

    local OriginalURL, OriginalURLorigin, OriginalFormat;                       -- TODO: swap chapter and title here so that archive applies to most specific if both are set?
    DeadURL = DeadURL:lower();                                                  -- used later when assembling archived text
    if is_set( ArchiveURL ) then
        if is_set (URL) then
            OriginalURL = URL;                                                  -- save copy of original source URL
            OriginalURLorigin = URLorigin;                                      -- name of url parameter for error messages
            OriginalFormat = Format;                                            -- and original |format=
            if 'no' ~= DeadURL then                                             -- if URL set then archive-url applies to it
                URL = ArchiveURL                                                -- swap-in the archive's url
                URLorigin = A:ORIGIN('ArchiveURL')                              -- name of archive url parameter for error messages
                Format = ArchiveFormat or '';                                   -- swap in archive's format
            end
        elseif is_set (ChapterURL) then                                         -- URL not set so if chapter-url is set apply archive url to it
            OriginalURL = ChapterURL;                                           -- save copy of source chapter's url for archive text
            OriginalURLorigin = ChapterURLorigin;                               -- name of chapter-url parameter for error messages
            OriginalFormat = ChapterFormat;                                     -- and original |format=
            if 'no' ~= DeadURL then
                ChapterURL = ArchiveURL                                         -- swap-in the archive's url
                ChapterURLorigin = A:ORIGIN('ArchiveURL')                       -- name of archive-url parameter for error messages
                ChapterFormat = ArchiveFormat or '';                            -- swap in archive's format
            end
        end
    end

    if in_array(config.CitationClass, {'web','news','journal', 'magazine', 'pressrelease','podcast', 'newsgroup', 'arxiv'}) or  -- if any of the 'periodical' cites except encyclopedia
        ('citation' == config.CitationClass and is_set (Periodical) and not is_set (Encyclopedia)) then
            local chap_param;
            if is_set (Chapter) then                                            -- get a parameter name from one of these chapter related meta-parameters
                chap_param = A:ORIGIN ('Chapter')
            elseif is_set (TransChapter) then
                chap_param = A:ORIGIN ('TransChapter')
            elseif is_set (ChapterURL) then
                chap_param = A:ORIGIN ('ChapterURL')
            elseif is_set (ScriptChapter) then
                chap_param = A:ORIGIN ('ScriptChapter')
            else is_set (ChapterFormat)
                chap_param = A:ORIGIN ('ChapterFormat')
            end

            if is_set (chap_param) then                                         -- if we found one
                table.insert( z.message_tail, { set_error( 'chapter_ignored', {chap_param}, true ) } );     -- add error message
                Chapter = '';                                                   -- and set them to empty string to be safe with concatenation
                TransChapter = '';
                ChapterURL = '';
                ScriptChapter = '';
                ChapterFormat = '';
            end
    else                                                                        -- otherwise, format chapter / article title
        local no_quotes = false;                                                -- default assume that we will be quoting the chapter parameter value
        if is_set (Contribution) and 0 < #c then                                -- if this is a contribution with contributor(s)
            if in_array (Contribution:lower(), cfg.keywords.contribution) then  -- and a generic contribution title
                no_quotes = true;                                               -- then render it unquoted
            end
        end

        Chapter = format_chapter_title (ScriptChapter, Chapter, TransChapter, ChapterURL, ChapterURLorigin, no_quotes);     -- Contribution is also in Chapter
        if is_set (Chapter) then
            if 'map' == config.CitationClass and is_set (TitleType) then
                Chapter = Chapter .. ' ' .. TitleType;
            end
            Chapter = Chapter .. ChapterFormat .. sepc .. ' ';
        elseif is_set (ChapterFormat) then                                      -- |chapter= not set but |chapter-format= is so ...
            Chapter = ChapterFormat .. sepc .. ' ';                             -- ... ChapterFormat has error message, we want to see it
        end
    end

    -- Format main title.
    if is_set(TitleLink) and is_set(Title) then
        Title = "[[" .. TitleLink .. "|" .. Title .. "]]"
    end

    if in_array(config.CitationClass, {'web','news','journal', 'magazine', 'pressrelease','podcast', 'newsgroup', 'mailinglist', 'arxiv'}) or
        ('citation' == config.CitationClass and is_set (Periodical) and not is_set (Encyclopedia)) or
        ('map' == config.CitationClass and is_set (Periodical)) then            -- special case for cite map when the map is in a periodical treat as an article
            Title = kern_quotes (Title);                                        -- if necessary, separate title's leading and trailing quote marks from Module provided quote marks
            Title = wrap_style ('quoted-title', Title);
    
            Title = script_concatenate (Title, ScriptTitle);                    -- <bdi> tags, lang atribute, categorization, etc; must be done after title is wrapped
            TransTitle= wrap_style ('trans-quoted-title', TransTitle );
    elseif 'report' == config.CitationClass then                                -- no styling for cite report
        Title = script_concatenate (Title, ScriptTitle);                        -- <bdi> tags, lang atribute, categorization, etc; must be done after title is wrapped
        TransTitle= wrap_style ('trans-quoted-title', TransTitle );             -- for cite report, use this form for trans-title
    else
        Title = wrap_style ('italic-title', Title);
        Title = script_concatenate (Title, ScriptTitle);                        -- <bdi> tags, lang atribute, categorization, etc; must be done after title is wrapped
        TransTitle = wrap_style ('trans-italic-title', TransTitle);
    end

    TransError = "";
    if is_set(TransTitle) then
        if is_set(Title) then
            TransTitle = " " .. TransTitle;
        else
            TransError = " " .. set_error( 'trans_missing_title', {'title'} );
        end
    end
    
    Title = Title .. TransTitle;
    
    if is_set(Title) then
        if not is_set(TitleLink) and is_set(URL) then 
            Title = external_link( URL, Title, URLorigin ) .. TransError .. Format;
            URL = "";
            Format = "";
        else
            Title = Title .. TransError;
        end
    end

    if is_set(Place) then
        Place = " " .. wrap_msg ('written', Place, use_lowercase) .. sepc .. " ";
    end

    if is_set (Conference) then
        if is_set (ConferenceURL) then
            Conference = external_link( ConferenceURL, Conference, ConferenceURLorigin );
        end
        Conference = sepc .. " " .. Conference .. ConferenceFormat;
    elseif is_set(ConferenceURL) then
        Conference = sepc .. " " .. external_link( ConferenceURL, nil, ConferenceURLorigin );
    end

    if not is_set(Position) then
        local Minutes = A['Minutes'];
        local Time = A['Time'];

        if is_set(Minutes) then
            if is_set (Time) then
                table.insert( z.message_tail, { set_error( 'redundant_parameters', {wrap_style ('parameter', 'minutes') .. ' and ' .. wrap_style ('parameter', 'time')}, true ) } );
            end
            Position = " " .. Minutes .. " " .. cfg.messages['minutes'];
        else
            if is_set(Time) then
                local TimeCaption = A['TimeCaption']
                if not is_set(TimeCaption) then
                    TimeCaption = cfg.messages['event'];
                    if sepc ~= '.' then
                        TimeCaption = TimeCaption:lower();
                    end
                end
                Position = " " .. TimeCaption .. " " .. Time;
            end
        end
    else
        Position = " " .. Position;
        At = '';
    end

    Page, Pages, Sheet, Sheets = format_pages_sheets (Page, Pages, Sheet, Sheets, config.CitationClass, Periodical_origin, sepc, NoPP, use_lowercase);

    At = is_set(At) and (sepc .. " " .. At) or "";
    Position = is_set(Position) and (sepc .. " " .. Position) or "";
    if config.CitationClass == 'map' then
        local Section = A['Section'];
        local Sections = A['Sections'];
        local Inset = A['Inset'];
        
        if is_set( Inset ) then
            Inset = sepc .. " " .. wrap_msg ('inset', Inset, use_lowercase);
        end         

        if is_set( Sections ) then
            Section = sepc .. " " .. wrap_msg ('sections', Sections, use_lowercase);
        elseif is_set( Section ) then
            Section = sepc .. " " .. wrap_msg ('section', Section, use_lowercase);
        end
        At = At .. Inset .. Section;        
    end 

    Language="";                                                            -- language not specified so make sure this is an empty string;

    Others = is_set(Others) and (sepc .. " " .. Others) or "";
    
    if is_set (Translators) then
        Others = sepc .. ' Translated by ' .. Translators .. Others; 
    end

    TitleNote = is_set(TitleNote) and (sepc .. " " .. TitleNote) or "";
    if is_set (Edition) then
        if Edition:match ('%f[%a][Ee]d%.?$') or Edition:match ('%f[%a][Ee]dition$') then
            add_maint_cat ('extra_text', 'edition');
        end
        Edition = " " .. wrap_msg ('edition', Edition);
    else
        Edition = '';
    end

    Series = is_set(Series) and (sepc .. " " .. Series) or "";
    OrigYear = is_set(OrigYear) and (" [" .. OrigYear .. "]") or "";
    Agency = is_set(Agency) and (sepc .. " " .. Agency) or "";

    Volume = format_volume_issue (Volume, Issue, config.CitationClass, Periodical_origin, sepc, use_lowercase);

    ------------------------------------ totally unrelated data
    if is_set(Via) then
        Via = " " .. wrap_msg ('via', Via);
    end

--[[
Subscription implies paywall; Registration does not.  If both are used in a citation, the subscription required link
note is displayed. There are no error messages for this condition.

]]
    if is_set (SubscriptionRequired) then
        SubscriptionRequired = sepc .. " " .. cfg.messages['subscription'];     -- subscription required message
    elseif is_set (RegistrationRequired) then
        SubscriptionRequired = sepc .. " " .. cfg.messages['registration'];     -- registration required message
    else
        SubscriptionRequired = '';                                              -- either or both might be set to something other than yes true y
    end

    if is_set(AccessDate) then
        local retrv_text = " " .. cfg.messages['retrieved']

        AccessDate = nowrap_date (AccessDate);                                  -- wrap in nowrap span if date in appropriate format
        if (sepc ~= ".") then retrv_text = retrv_text:lower() end               -- if 'citation', lower case
        AccessDate = substitute (retrv_text, AccessDate);                       -- add retrieved text
                                                                                -- neither of these work; don't know why; it seems that substitute() isn't being called 
        AccessDate = substitute (cfg.presentation['accessdate'], {sepc, AccessDate});   -- allow editors to hide accessdates
    end
    
    if is_set(ID) then ID = sepc .." ".. ID; end
    if "thesis" == config.CitationClass and is_set(Docket) then
        ID = sepc .." Docket ".. Docket .. ID;
    end
    if "report" == config.CitationClass and is_set(Docket) then                 -- for cite report when |docket= is set
        ID = sepc .. ' ' .. Docket;                                             -- overwrite ID even if |id= is set
    end

    ID_list = build_id_list( ID_list, {DoiBroken = DoiBroken, ASINTLD = ASINTLD, IgnoreISBN = IgnoreISBN, Embargo=Embargo, Class = Class} );

    if is_set(URL) then
        URL = " " .. external_link( URL, nil, URLorigin );
    end

    if is_set(Quote) then
        if Quote:sub(1,1) == '"' and Quote:sub(-1,-1) == '"' then               -- if first and last characters of quote are quote marks
            Quote = Quote:sub(2,-2);                                            -- strip them off
        end
        Quote = sepc .." " .. wrap_style ('quoted-text', Quote );               -- wrap in <q>...</q> tags
        PostScript = "";                                                        -- cs1|2 does not supply terminal punctuation when |quote= is set
    end
    
    local Archived
    if is_set(ArchiveURL) then
        if not is_set(ArchiveDate) then
            ArchiveDate = set_error('archive_missing_date');
        end
        if "no" == DeadURL then
            local arch_text = cfg.messages['archived'];
            if sepc ~= "." then arch_text = arch_text:lower() end
            Archived = sepc .. " " .. substitute( cfg.messages['archived-not-dead'],
                { external_link( ArchiveURL, arch_text, A:ORIGIN('ArchiveURL') ) .. ArchiveFormat, ArchiveDate } );
            if not is_set(OriginalURL) then
                Archived = Archived .. " " .. set_error('archive_missing_url');                            
            end
        elseif is_set(OriginalURL) then                                         -- DeadURL is empty, 'yes', 'true', 'y', 'unfit', 'usurped'
            local arch_text = cfg.messages['archived-dead'];
            if sepc ~= "." then arch_text = arch_text:lower() end
            if in_array (DeadURL, {'unfit', 'usurped'}) then
                Archived = sepc .. " " .. 'Archived from the original on ' .. ArchiveDate;  -- format already styled
            else                                                                -- DeadURL is empty, 'yes', 'true', or 'y'
                Archived = sepc .. " " .. substitute( arch_text,
                    { external_link( OriginalURL, cfg.messages['original'], OriginalURLorigin ) .. OriginalFormat, ArchiveDate } ); -- format already styled
            end 
        else
            local arch_text = cfg.messages['archived-missing'];
            if sepc ~= "." then arch_text = arch_text:lower() end
            Archived = sepc .. " " .. substitute( arch_text, 
                { set_error('archive_missing_url'), ArchiveDate } );
        end
    elseif is_set (ArchiveFormat) then
        Archived = ArchiveFormat;                                               -- if set and ArchiveURL not set ArchiveFormat has error message
    else
        Archived = ""
    end
    
    local Lay = '';
    if is_set(LayURL) then
        if is_set(LayDate) then LayDate = " (" .. LayDate .. ")" end
        if is_set(LaySource) then 
            LaySource = " &ndash; ''" .. safe_for_italics(LaySource) .. "''";
        else
            LaySource = "";
        end
        if sepc == '.' then
            Lay = sepc .. " " .. external_link( LayURL, cfg.messages['lay summary'], A:ORIGIN('LayURL') ) .. LayFormat .. LaySource .. LayDate
        else
            Lay = sepc .. " " .. external_link( LayURL, cfg.messages['lay summary']:lower(), A:ORIGIN('LayURL') ) .. LayFormat .. LaySource .. LayDate
        end         
    elseif is_set (LayFormat) then                                              -- Test if |lay-format= is given without giving a |lay-url=
        Lay = sepc .. LayFormat;                                                -- if set and LayURL not set, then LayFormat has error message
    end

    if is_set(Transcript) then
        if is_set(TranscriptURL) then
            Transcript = external_link( TranscriptURL, Transcript, TranscriptURLorigin );
        end
        Transcript = sepc .. ' ' .. Transcript .. TranscriptFormat;
    elseif is_set(TranscriptURL) then
        Transcript = external_link( TranscriptURL, nil, TranscriptURLorigin );
    end

    local Publisher;
    if is_set(Periodical) and
        not in_array(config.CitationClass, {"encyclopaedia","web","pressrelease","podcast"}) then
        if is_set(PublisherName) then
            if is_set(PublicationPlace) then
                Publisher = PublicationPlace .. ": " .. PublisherName;
            else
                Publisher = PublisherName;  
            end
        elseif is_set(PublicationPlace) then
            Publisher= PublicationPlace;
        else 
            Publisher = "";
        end
        if is_set(PublicationDate) then
            if is_set(Publisher) then
                Publisher = Publisher .. ", " .. wrap_msg ('published', PublicationDate);
            else
                Publisher = PublicationDate;
            end
        end
        if is_set(Publisher) then
            Publisher = " (" .. Publisher .. ")";
        end
    else
        if is_set(PublicationDate) then
            PublicationDate = " (" .. wrap_msg ('published', PublicationDate) .. ")";
        end
        if is_set(PublisherName) then
            if is_set(PublicationPlace) then
                Publisher = sepc .. " " .. PublicationPlace .. ": " .. PublisherName .. PublicationDate;
            else
                Publisher = sepc .. " " .. PublisherName .. PublicationDate;  
            end         
        elseif is_set(PublicationPlace) then 
            Publisher= sepc .. " " .. PublicationPlace .. PublicationDate;
        else 
            Publisher = PublicationDate;
        end
    end
    
    -- Several of the above rely upon detecting this as nil, so do it last.
    if is_set(Periodical) then
        if is_set(Title) or is_set(TitleNote) then 
            Periodical = sepc .. " " .. wrap_style ('italic-title', Periodical) 
        else 
            Periodical = wrap_style ('italic-title', Periodical)
        end
    end

--[[
Handle the oddity that is cite speech.  This code overrides whatever may be the value assigned to TitleNote (through |department=) and forces it to be " (Speech)" so that
the annotation directly follows the |title= parameter value in the citation rather than the |event= parameter value (if provided).
]]
    if "speech" == config.CitationClass then                -- cite speech only
        TitleNote = " (Speech)";                            -- annotate the citation
        if is_set (Periodical) then                         -- if Periodical, perhaps because of an included |website= or |journal= parameter 
            if is_set (Conference) then                     -- and if |event= is set
                Conference = Conference .. sepc .. " ";     -- then add appropriate punctuation to the end of the Conference variable before rendering
            end
        end
    end

    -- Piece all bits together at last.  Here, all should be non-nil.
    -- We build things this way because it is more efficient in LUA
    -- not to keep reassigning to the same string variable over and over.

    local tcommon;
    local tcommon2;                                                             -- used for book cite when |contributor= is set
    
    if in_array(config.CitationClass, {"journal","citation"}) and is_set(Periodical) then
        if is_set(Others) then Others = Others .. sepc .. " " end
        tcommon = safe_join( {Others, Title, TitleNote, Conference, Periodical, Format, TitleType, Series, 
            Language, Edition, Publisher, Agency, Volume}, sepc );
        
    elseif in_array(config.CitationClass, {"book","citation"}) and not is_set(Periodical) then      -- special cases for book cites
        if is_set (Contributors) then                                           -- when we are citing foreword, preface, introduction, etc
            tcommon = safe_join( {Title, TitleNote}, sepc );                    -- author and other stuff will come after this and before tcommon2
            tcommon2 = safe_join( {Conference, Periodical, Format, TitleType, Series, Language, Volume, Others, Edition, Publisher, Agency}, sepc );
        else
            tcommon = safe_join( {Title, TitleNote, Conference, Periodical, Format, TitleType, Series, Language, Volume, Others, Edition, Publisher, Agency}, sepc );
        end

    elseif 'map' == config.CitationClass then                                   -- special cases for cite map
        if is_set (Chapter) then                                                -- map in a book; TitleType is part of Chapter
            tcommon = safe_join( {Title, Format, Edition, Scale, Series, Language, Cartography, Others, Publisher, Volume}, sepc );
        elseif is_set (Periodical) then                                         -- map in a periodical
            tcommon = safe_join( {Title, TitleType, Format, Periodical, Scale, Series, Language, Cartography, Others, Publisher, Volume}, sepc );
        else                                                                    -- a sheet or stand-alone map
            tcommon = safe_join( {Title, TitleType, Format, Edition, Scale, Series, Language, Cartography, Others, Publisher}, sepc );
        end
        
    elseif 'episode' == config.CitationClass then                               -- special case for cite episode
        tcommon = safe_join( {Title, TitleNote, TitleType, Series, Transcript, Language, Edition, Publisher}, sepc );
    else                                                                        -- all other CS1 templates
        tcommon = safe_join( {Title, TitleNote, Conference, Periodical, Format, TitleType, Series, Language, 
            Volume, Others, Edition, Publisher, Agency}, sepc );
    end
    
    if #ID_list > 0 then
        ID_list = safe_join( { sepc .. " ",  table.concat( ID_list, sepc .. " " ), ID }, sepc );
    else
        ID_list = ID;
    end
    
    local idcommon = safe_join( { ID_list, URL, Archived, AccessDate, Via, SubscriptionRequired, Lay, Quote }, sepc );
    local text;
    local pgtext = Position .. Sheet .. Sheets .. Page .. Pages .. At;

    if is_set(Date) then
        if is_set (Authors) or is_set (Editors) then                            -- date follows authors or editors when authors not set
            Date = " (" .. Date ..")" .. OrigYear .. sepc .. " ";               -- in paranetheses
        else                                                                    -- neither of authors and editors set
            if (string.sub(tcommon,-1,-1) == sepc) then                         -- if the last character of tcommon is sepc
                Date = " " .. Date .. OrigYear;                                 -- Date does not begin with sepc
            else
                Date = sepc .. " " .. Date .. OrigYear;                         -- Date begins with sepc
            end
        end
    end 
    if is_set(Authors) then
        if is_set(Coauthors) then
            if 'vanc' == NameListFormat then                                    -- separate authors and coauthors with proper name-list-separator
                Authors = Authors .. ', ' .. Coauthors;
            else
                Authors = Authors .. '; ' .. Coauthors;
            end
        end
        if not is_set (Date) then                                               -- when date is set it's in parentheses; no Authors termination
            Authors = terminate_name_list (Authors, sepc);                      -- when no date, terminate with 0 or 1 sepc and a space
        end
        if is_set(Editors) then
            local in_text = " ";
            local post_text = "";
            if is_set(Chapter) and 0 == #c then
                in_text = in_text .. cfg.messages['in'] .. " "
                if (sepc ~= '.') then in_text = in_text:lower() end             -- lowercase for cs2
            else
                if EditorCount <= 1 then
                    post_text = ", " .. cfg.messages['editor'];
                else
                    post_text = ", " .. cfg.messages['editors'];
                end
            end 
            Editors = terminate_name_list (in_text .. Editors .. post_text, sepc);  -- terminate with 0 or 1 sepc and a space
        end
        if is_set (Contributors) then                                           -- book cite and we're citing the intro, preface, etc
            local by_text = sepc .. ' ' .. cfg.messages['by'] .. ' ';
            if (sepc ~= '.') then by_text = by_text:lower() end                 -- lowercase for cs2
            Authors = by_text .. Authors;                                       -- author follows title so tweak it here
            if is_set (Editors) then                                            -- when Editors make sure that Authors gets terminated
                Authors = terminate_name_list (Authors, sepc);                  -- terminate with 0 or 1 sepc and a space
            end
            if not is_set (Date) then                                           -- when date is set it's in parentheses; no Contributors termination
                Contributors = terminate_name_list (Contributors, sepc);        -- terminate with 0 or 1 sepc and a space
            end
            text = safe_join( {Contributors, Date, Chapter, tcommon, Authors, Place, Editors, tcommon2, pgtext, idcommon }, sepc );
        else
            text = safe_join( {Authors, Date, Chapter, Place, Editors, tcommon, pgtext, idcommon }, sepc );
        end
    elseif is_set(Editors) then
        if is_set(Date) then
            if EditorCount <= 1 then
                Editors = Editors .. ", " .. cfg.messages['editor'];
            else
                Editors = Editors .. ", " .. cfg.messages['editors'];
            end
        else
            if EditorCount <= 1 then
                Editors = Editors .. " (" .. cfg.messages['editor'] .. ")" .. sepc .. " "
            else
                Editors = Editors .. " (" .. cfg.messages['editors'] .. ")" .. sepc .. " "
            end
        end
        text = safe_join( {Editors, Date, Chapter, Place, tcommon, pgtext, idcommon}, sepc );
    else
        if config.CitationClass=="journal" and is_set(Periodical) then
            text = safe_join( {Chapter, Place, tcommon, pgtext, Date, idcommon}, sepc );
        else
            text = safe_join( {Chapter, Place, tcommon, Date, pgtext, idcommon}, sepc );
        end
    end
    
    if is_set(PostScript) and PostScript ~= sepc then
        text = safe_join( {text, sepc}, sepc );  --Deals with italics, spaces, etc.
        text = text:sub(1,-sepc:len()-1);
    end 
    
    text = safe_join( {text, PostScript}, sepc );

    -- Now enclose the whole thing in a <cite/> element
    local options = {};
    
    if is_set(config.CitationClass) and config.CitationClass ~= "citation" then
        options.class = config.CitationClass;
        options.class = "citation " .. config.CitationClass;                    -- class=citation required for blue highlight when used with |ref=
    else
        options.class = "citation";
    end
    
    if is_set(Ref) and Ref:lower() ~= "none" then                               -- set reference anchor if appropriate
        local id = Ref
        if ('harv' == Ref ) then
            local namelist = {};                                                -- holds selected contributor, author, editor name list
--          local year = first_set (Year, anchor_year);                         -- Year first for legacy citations and for YMD dates that require disambiguation
            local year = first_set ({Year, anchor_year}, 2);                    -- Year first for legacy citations and for YMD dates that require disambiguation

            if #c > 0 then                                                      -- if there is a contributor list
                namelist = c;                                                   -- select it
            elseif #a > 0 then                                                  -- or an author list
                namelist = a;
            elseif #e > 0 then                                                  -- or an editor list
                namelist = e;
            end
            id = anchor_id (namelist, year);                                    -- go make the CITEREF anchor
        end
        options.id = id;
    end
    
    if string.len(text:gsub("<span[^>/]*>.-</span>", ""):gsub("%b<>","")) <= 2 then
        z.error_categories = {};
        text = set_error('empty_citation');
        z.message_tail = {};
    end
    
--    if is_set(options.id) then 
--        text = '<cite id="' .. export_uri_anchorEncode(options.id) ..'" class="' .. export_text_nowiki(options.class) .. '">' .. text .. "</cite>";
--    else
--        text = '<cite class="' .. export_text_nowiki(options.class) .. '">' .. text .. "</cite>";
--    end     

    local empty_span = '<span style="display:none;">&nbsp;</span>';
    
    -- Note: Using display: none on the COinS span breaks some clients.
    local OCinS = '<span title="' .. OCinSoutput .. '" class="Z3988">' .. empty_span .. '</span>';
    text = text .. OCinS;
    
    if #z.message_tail ~= 0 then
        text = text .. " ";
        for i,v in ipairs( z.message_tail ) do
            if is_set(v[1]) then
                if i == #z.message_tail then
                    text = text .. error_comment( v[1], v[2] );
                else
                    text = text .. error_comment( v[1] .. "; ", v[2] );
                end
            end
        end
    end

    if #z.maintenance_cats ~= 0 then
        text = text .. '<span class="citation-comment" style="display:none; color:#33aa33">';
        for _, v in ipairs( z.maintenance_cats ) do                             -- append maintenance categories
            text = text .. ' ' .. v .. ' ([[:Category:' .. v ..'|link]])';
        end
        text = text .. '</span>';   -- maintenance mesages (realy just the names of the categories for now)
    end
    
    no_tracking_cats = no_tracking_cats:lower();
    if in_array(no_tracking_cats, {"", "no", "false", "n"}) then
        for _, v in ipairs( z.error_categories ) do
            text = text .. '[[Category:' .. v ..']]';
        end
        for _, v in ipairs( z.maintenance_cats ) do                             -- append maintenance categories
            text = text .. '[[Category:' .. v ..']]';
        end
        for _, v in ipairs( z.properties_cats ) do                              -- append maintenance categories
            text = text .. '[[Category:' .. v ..']]';
        end
    end
    
    return text
end

--[[--------------------------< H A S _ I N V I S I B L E _ C H A R S >----------------------------------------

This function searches a parameter's value for nonprintable or invisible characters.  The search stops at the first match.

Sometime after this module is done with rendering a citation, some C0 control characters are replaced with the
replacement character.  That replacement character is not detected by this test though it is visible to readers
of the rendered citation.  This function will detect the replacement character when it is part of the wikisource.

Output of this function is an error message that identifies the character or the Unicode group that the character
belongs to along with its position in the parameter value.

]]
--[[
local function has_invisible_chars (param, v)
    local position = '';
    local i=1;

    while cfg.invisible_chars[i] do
        local char=cfg.invisible_chars[i][1]                                    -- the character or group name
        local pattern=cfg.invisible_chars[i][2]                                 -- the pattern used to find it
        v = export_text_unstripNoWiki( v );                                         -- remove nowiki stripmarkers
        position = export_ustring_find (v, pattern)                                 -- see if the parameter value contains characters that match the pattern
        if position then
            table.insert( z.message_tail, { set_error( 'invisible_char', {char, wrap_style ('parameter', param), position}, true ) } ); -- add error message
            return;                                                             -- and done with this parameter
        end
        i=i+1;                                                                  -- bump our index
    end
end
]]

--[[--------------------------< Z . C I T A T I O N >----------------------------------------------------------

This is used by templates such as {{cite book}} to create the actual citation text.

]]

local function cite_args(orig_args)
    local args = {};
    local suggestions = {};
    local error_text, error_state;

    local config = {};

    for k, v in pairs( orig_args ) do
        config[k] = v;
        args[k] = v;       
    end

    local capture;                                                              -- the single supported capture when matching unknown parameters using patterns
    for k, v in pairs( orig_args ) do
        if v ~= '' then
            if not validate( k ) then           
                error_text = "";
                if type( k ) ~= 'string' then
                    -- Exclude empty numbered parameters
                    if v:match("%S+") ~= nil then
                        error_text, error_state = set_error( 'text_ignored', {v}, true );
                    end
                elseif validate( k:lower() ) then 
                    error_text, error_state = set_error( 'parameter_ignored_suggest', {k, k:lower()}, true );
                else
                    if not is_set (error_text) then                             -- couldn't match with a pattern, is there an expicit suggestion?
                        error_text, error_state = set_error( 'parameter_ignored', {k}, true );
                    end
                end               
                if error_text ~= '' then
                    table.insert( z.message_tail, {error_text, error_state} );
                end             
            end
            args[k] = v;
        elseif args[k] ~= nil or (k == 'postscript') then
            args[k] = v;
        end     
    end 

    for k, v in pairs( args ) do
        if 'string' == type (k) then                                            -- don't evaluate positional parameters
            has_invisible_chars (k, v);
        end
    end

    return citation0( config, args)
end

local sample2 = {
     archivedate = '7 November 2012',
     publisher = 'International Group of San Francisco',
     last = 'Malatesta',
     title = 'Towards Anarchism',
     oclc = '3930443',
     journal = 'MAN!',
     authorlink = 'Errico Malatesta',
     archiveurl = 'https://web.archive.org/web/20121107221404/http://marxists.org/archive/malatesta/1930s/xx/toanarchy.htm',
     url = 'http://www.marxists.org/archive/malatesta/1930s/xx/toanarchy.htm',
     deadurl = 'no',
     location = 'Los Angeles',
     ref = 'harv',
     first = 'Errico'
    };


return cite_args( sample );
end

