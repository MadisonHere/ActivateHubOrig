require 'spec_helper'

def events_from_ical_at(filename)
  url = "http://foo.bar/"
  source = Source.new(:title => "Calendar event feed", :url => url)
  SourceParser::Base.should_receive(:read_url).and_return(read_sample(filename))
  return source.to_events(:skip_old => false)
end

RSpec.describe SourceParser::Ical, "in general" do
  it "should read http URLs as-is" do
    http_url = "http://foo.bar/"
    stub_source_parser_http_response!(:body => 42)

    SourceParser::Ical.read_url(http_url).should eq 42
  end

  it "should read webcal URLs as http" do
    webcal_url = "webcal://foo.bar/"
    http_url   = "http://foo.bar/"
    stub_source_parser_http_response!(:body => 42)
    SourceParser::Ical.read_url(webcal_url).should eq 42
  end
end

RSpec.describe SourceParser::Ical, "when parsing events and their locations" do

  before(:each) do
    SourceParser::Base.should_receive(:read_url).and_return(read_sample('ical_eventful_many.ics'))
    @events = SourceParser.to_abstract_events(:url => "intercepted", :skip_old => false)
  end

   it "locations should be" do
    @events.each do |event|
      event.abstract_location.should_not be_nil
    end
  end

end

RSpec.describe SourceParser::Ical, "when parsing multiple items in an Eventful feed" do
  before(:each) do
    SourceParser::Base.should_receive(:read_url).and_return(read_sample('ical_eventful_many.ics'))
    @events = SourceParser.to_abstract_events(:url => "intercepted", :skip_old => false)
  end

  it "should find multiple events" do
    @events.size.should eq 15
  end

  it "should find venues for events" do
    @events.each do |event|
      event.abstract_location.title.should_not be_nil
    end
  end

  it "should match each event with its venue" do
    event_titles_and_street_addresses = [
      ["iMovie and iDVD Workshop", "7293 SW Bridgeport Road"],
      ["Portland Macintosh Users Group (PMUG)", "Jean Vollum Natural Capital Center"],
      ["Morning Meetings: IT", "622 SE Grand Avenue"]
    ]

    # Make sure each of the above events has the expected street address
    event_titles_and_street_addresses.each do |event_title, street_address|
      @events.find { |event|
        event.title == event_title && event.abstract_location.street_address == street_address
        }.should_not be_nil
      end
  end
end

RSpec.describe SourceParser::Ical, "with iCalendar events" do

  it "should parse Apple iCalendar v3 format" do
    events = events_from_ical_at('ical_apple_v3.ics')

    events.size.should eq 1
    event = events.first
    event.title.should eq "Coffee with Jason"
    # NOTE Source data does not contain a timezone!?
    event.start_time.should eq Time.zone.parse('2010-04-08 00:00:00')
    event.end_time.should eq Time.zone.parse('2010-04-08 01:00:00')
    event.venue.should be_nil
  end

  it "should parse basic iCalendar format" do
    events = events_from_ical_at('ical_basic.ics')

    events.size.should eq 1
    event = events.first
    event.title.should be_blank
    event.start_time.should eq Time.zone.parse('Thu Jan 17 00:00:00 2013')
    event.venue.should be_nil
  end

  it "should parse basic iCalendar format with a duration and set the correct end time" do
    events = events_from_ical_at('ical_basic_with_duration.ics')

    events.size.should eq 1
    event = events.first
    event.title.should be_blank
    event.start_time.should eq Time.zone.parse('2010-04-08 00:00:00')
    event.end_time.should eq Time.zone.parse('2010-04-08 01:00:00')
    event.venue.should be_nil
  end

  it "should parse Google iCalendar feed with multiple events" do
    events = events_from_ical_at('ical_google.ics')
    # TODO add specs for venues/locations

    events.size.should eq 47

    event = events.first
    event.title.should eq "XPDX (eXtreme Programming) at CubeSpace"
    event.description.should be_blank
    event.start_time.should eq Time.zone.parse("2012-10-24 15:30:00")
    event.end_time.should eq Time.zone.parse("2012-10-24 20:30:00")

    event = events[17]
    event.title.should eq "Code Sprint/Coding Dojo at CubeSpace"
    event.description.should be_blank
    event.start_time.should eq Time.zone.parse("2012-10-17 20:00:00")
    event.end_time.should eq Time.zone.parse("2012-10-17 22:00:00")

    event = events.last
    event.title.should eq "Adobe Developer User Group"
    event.description.should eq "http://pdxria.com/"
    event.start_time.should eq Time.zone.parse("2012-01-16 17:30:00")
    event.end_time.should eq Time.zone.parse("2012-01-16 18:30:00")
  end

  it "should parse non-Vcard locations" do
    events = events_from_ical_at('ical_google.ics')
    events.first.venue.title.should eq 'CubeSpace'
  end

  it "should parse a calendar file with multiple calendars" do
    events = events_from_ical_at('ical_multiple_calendars.ics')
    events.size.should eq 3
    events.map(&:title).should eq ["Coffee with Jason", "Coffee with Mike", "Coffee with Kim"]
  end

end

RSpec.describe SourceParser::Ical, "when importing events with non-local times" do

  it "should store time ending in Z as UTC" do
    url = "http://foo.bar/"
    SourceParser::Base.stub(:read_url).and_return(read_sample('ical_z.ics'))
    @source = Source.new(:title => "Non-local time", :url => url)
    events = @source.create_events!(:skip_old => false)
    event = events.first

    event.start_time.should eq Time.zone.parse('Thu Jul 01 08:00:00 +0000 2010')
    event.end_time.should eq Time.zone.parse('Thu Jul 01 09:00:00 +0000 2010')

    # time should be the same after saving event to, and getting it from, database
    event.save
    e = Event.find(event)
    e.start_time.should eq Time.zone.parse('Thu Jul 01 08:00:00 +0000 2010')
    e.end_time.should eq Time.zone.parse('Thu Jul 01 09:00:00 +0000 2010')
  end

  it "should store time with TZID=GMT in UTC" do
    pending "RiCal doesn't consider the time zone data in this file valid"
    events = events_from_ical_at('ical_gmt.ics')
    events.size.should eq 1
    abstract_event = events.first
    abstract_event.start_time.should eq Time.zone.parse('Fri May 07 08:00:00 +0000 2020')
    abstract_event.end_time.should eq Time.zone.parse('Fri May 07 09:00:00 +0000 2020')
  end

end

RSpec.describe SourceParser::Ical, "when skipping old events" do
  before(:each) do
    SourceParser::Base.stub(:read_url).and_return(<<-HERE)
BEGIN:VCALENDAR
X-WR-CALNAME;VALUE=TEXT:NERV
VERSION:2.0
CALSCALE:GREGORIAN
PRODID:-//nerv.go.jp//iCal 1.0//EN
X-WR-TIMEZONE;VALUE=TEXT:US/Eastern
BEGIN:VEVENT
UID:Unit-01
SUMMARY:Past start and no end
DESCRIPTION:Ayanami
DTSTART:#{(Time.zone.now-3.months).strftime("%Y%m%d")}
DTSTAMP:040425
SEQ:0
END:VEVENT
BEGIN:VEVENT
UID:Unit-02
SUMMARY:Current start and no end
DESCRIPTION:Soryu
DTSTART:#{(Time.zone.now+3.months).strftime("%Y%m%d")}
DTSTAMP:040425
SEQ:1
END:VEVENT
BEGIN:VEVENT
UID:Unit-03
SUMMARY:Past start and current end
DESCRIPTION:Soryu a
DTSTART:#{(Time.zone.now-3.months).strftime("%Y%m%d")}
DTEND:#{(Time.zone.now+3.months).strftime("%Y%m%d")}
DTSTAMP:040425
END:VEVENT
BEGIN:VEVENT
UID:Unit-04
SUMMARY:Current start and current end
DESCRIPTION:Soryu as
DTSTART:#{Time.zone.now.strftime("%Y%m%d")}
DTEND:#{(Time.zone.now+3.months).strftime("%Y%m%d")}
DTSTAMP:040425
END:VEVENT
BEGIN:VEVENT
UID:Unit-05
SUMMARY:Past start and past end
DESCRIPTION:Soryu qewr
DTSTART:#{(Time.zone.now-3.months).strftime("%Y%m%d")}
DTEND:#{(Time.zone.now-3.months).strftime("%Y%m%d")}
DTSTAMP:040425
END:VEVENT
BEGIN:VEVENT
UID:Unit-06
SUMMARY:Current start and past end
DESCRIPTION:Not a valid event
DTSTART:#{Time.zone.now.strftime("%Y%m%d")}
DTEND:#{(Time.zone.now-3.months).strftime("%Y%m%d")}
DTSTAMP:040425
END:VEVENT
END:VCALENDAR
      HERE
    @source = Source.new(:title => "Title", :url => "http://my.url/")
  end

  # for following specs a 'valid' event does not start after it ends"
  it "should be able to import all valid events" do
    events = @source.create_events!(:skip_old => false)
    events.size.should eq 5
    events.map(&:title).should eq [
      "Past start and no end",
      "Current start and no end",
      "Past start and current end",
      "Current start and current end",
      "Past start and past end"
    ]
  end

  it "should be able to skip invalid and old events" do
    events = @source.create_events!(:skip_old => true)
    events.size.should eq 3
    events.map(&:title).should eq [
      "Current start and no end",
      "Past start and current end",
      "Current start and current end"
    ]
  end

end
