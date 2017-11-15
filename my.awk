BEGIN {
    FS="\n"
    RS=""
    article_type = ""
    default_article_type = "faq"
    article_title = ""
    summary_field = ""
    the_csv = "test.csv"
    # print the header row to the csv
    print "Title,Summary,ArticleBody__c" > the_csv
}
{
    content_line = "2"
    current_line_is_header = "false"
}
{
    # get the article type from the article tag's class attribute

    # include a hyphen in the regex to accommodate the "how-to" class
    match($1, /class="[a-z-]*?"/)
    if (RSTART > 0) {
        start_class = RSTART + 7
        end_class = RLENGTH - 8
        article_type = substr($1, start_class, end_class)
    }
    else {
        article_type = default_article_type
    }
}
{
    # get the article title from between the h2 tags

    match($2, />[^<]*?<\//)
    if (RSTART > 0) {
        start_title = RSTART + 1
        end_title = RLENGTH - 3
        article_title = substr($2, start_title, end_title)
        content_line += 1
    }
    else {
        article_title = "Needs review: Fix article title"
    }
}
{
    # get the content between <h3>What it sounds like</h3> and <h3>What to say and do</h3>
    # and use it as the csv Summary field - but first, need to screen this content for html
    # step through the records to find content

    summary_field = ""
    {
        match($content_line, /What it sounds like/)
        if (RSTART > 0) {
            content_line += 1
            do {
                # the summary field only accepts raw text (no html content)
                summary_field = summary_field $content_line
                # p = nothing
                gsub(/<\/?p>/,"",summary_field)
                # list start = space
                gsub(/<[ou]l><li>/," ",summary_field)
                # li = comma
                gsub("<li>", ", ", summary_field)
                # /li = nothing
                gsub("</li>","",summary_field)
                # list end = period
                gsub(/<\/[ou]l>/, ".", summary_field)
                # also need to avoid double quotes because this goes in a csv file
                gsub("\"","",summary_field)
                content_line++
                match($content_line,/What to .*do/)
                if (RSTART > 0) {
                    current_line_is_header = "true"
                }
            } while ((content_line < NF) && (RSTART == 0))
        }
    }
}
{
    # send rest of article record to its own separate file
    # the file should not contain any of the content we have already processed and not the last line (an article end tag)
    x = 1
    do {
        $x = ""
        x++
    } while (x < content_line)
    if (current_line_is_header == "true") {
        $content_line = ""
    }
    $NF = ""

    # although the filename is based on the title, to ensure uniqueness, we will append a number
    shortened_name = substr(tolower(article_title),1,40)
    gsub(/[ \?\\\/]/,"-",shortened_name)
    this_filename = article_type "-" shortened_name NR ".html"

    # can uncomment this line for debugging
    print "Article type: " article_type " Title: " article_title " Summary: " summary_field " ArticleBody: " $0 "\n" > "logfile.txt"

    print > this_filename

    # we are sending to csv file, so keep title and summary fields in quotes because they often contain commas
    print "\"" article_title "\",\"" summary_field "\",\"" this_filename "\"" > the_csv
}