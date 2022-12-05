# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zip) # rubocop:disable Metrics/MethodLength
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue # rubocop:disable Style/RescueStandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def clean_phone_number(phone_number)
  phone_number.gsub!(/[^\d]/, '')
  if phone_number.length < 10 || phone_number.length > 11
    nil.to_s
  elsif phone_number.length == 11
    phone_number[0] == '1' ? phone_number.delete_prefix('1') : nil.to_s
  end
end

def format_date(date)
  Time.strptime(date, '%m/%d/%y %H:%M')
end

def find_peaks(counter)
  counter.select { |_, count| count == counter.values.max }
end

puts 'Event Manager Initialized!'

contents = CSV.open('event_attendees.csv', headers: true, header_converters: :symbol)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter
reg_hrs = Hash.new(0)
reg_days = Hash.new(0)

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  homephone = clean_phone_number(row[:homephone])
  regdate = format_date(row[:regdate])

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)

  reg_hr = regdate.hour.to_s.to_sym
  reg_hrs[reg_hr] += 1

  reg_day = regdate.strftime('%A').to_sym
  reg_days[reg_day] += 1
end

peak_registration_hrs = find_peaks(reg_hrs)
peak_registration_days = find_peaks(reg_days)

p %(Peak registration hours are #{peak_registration_hrs.map { |key, _| "#{key}:00" }.join(' and ')}
  \swith a total of #{peak_registration_hrs.values[0]} times.)

p %(Most people registered on #{peak_registration_days.map do |key, value|
                                  "#{key} with a total of #{value} times."
                                end.join("\n\s\s\s\s")})

contents.close
