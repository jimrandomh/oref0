#!/usr/bin/python
# This script converts the json files in the autotune directory
# to a Microsoft Excel file
#
# Released under MIT license. See the accompanying LICENSE.txt file for
# full terms and conditions
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

import json
import glob, os, sys

import datetime
import argparse
import re

def parseDateAndRun(filename):
    m=re.match( r'profile.(?P<run>.*).(?P<date>20[0-9][0-9]-[01][0-9]-[0-3][0-9]).json', filename)
    if m:
         return (m.group('date'), m.group('run'))
    else: # not found
        return ('-','-')

def calc_minutes(timestr):
    # returns the number of minutes from midnight. seconds are ignored
    # based on http://stackoverflow.com/questions/10663720/converting-a-time-string-to-seconds-in-python
    ftr = [60,1,0] # ignore seconds, count minutes, and use 60 minutes per hour
    return sum([a*b for a,b in zip(ftr, map(int,timestr.split(':')))])

def expandProfile(l, valueField, offsetField):
    r=[]
    minutes=0
    value=l[0][valueField]
    for i in range(len(l)):
        start1=l[i]['start']
        minutes1=calc_minutes(start1)
        offset1=l[i][offsetField]
        if minutes1!=offset1:
            print("Error in JSON offSetField %s contains %s does not match start time %s (%d minutes). Please report this as a bug" % (offsetField, offset1, start1, minutes1))
            sys.exit(1)
        while (minutes<minutes1):
            r.append(value)
            minutes=minutes+30
        value=l[i][valueField]
    # add the last value until midnight    
    while (minutes<24*60): 
        r.append(value)
        minutes=minutes+30
    # return the expanded profile
    return r

def writeExcelHeader(ws, date_format, headerFormat):
    ws.write_string(0,0, 'Filename', headerFormat)
    ws.write_string(0,1, 'Date', headerFormat)
    ws.write_string(0,2, 'Run', headerFormat)
    col=3
    for hours in range(24):
        for minutes in [0,30]:
            dt=datetime.datetime.strptime('%02d:%02d' % (hours,minutes) , '%H:%M')
            ws.write_datetime(0, col, dt, date_format)
            col=col+1

def write_excel_profile(worksheet, row, expandedList, excel_number_format):
    worksheet.write_string(row, 0, filename)
    date, run = parseDateAndRun(filename)
    worksheet.write_string(row, 1, date)
    worksheet.write_string(row, 2, run)
    col=3
    for i in range(len(expandedList)):
        worksheet.write_number(row, col, expandedList[i], excel_number_format)
        col=col+1

def excel_init_workbook(workbook):
    #see http://xlsxwriter.readthedocs.io/format.html#format for documentation on the Excel format's
    excel_hour_format = workbook.add_format({'num_format': 'hh:mm', 'bold': True, 'font_color': 'black'})
    excel_2decimals_format = workbook.add_format({'num_format': '0.00', 'font_size': '16'})
    excel_integer_format = workbook.add_format({'num_format': '0', 'font_size': '16'})
    headerFormat = workbook.add_format({'bold': True, 'font_color': 'black'})
    worksheetInfo = workbook.add_worksheet('Read this first')
    worksheetIsf = workbook.add_worksheet('isfProfile')
    worksheetBasal = workbook.add_worksheet('basalProfile') 
    writeExcelHeader(worksheetBasal, excel_hour_format,headerFormat)
    writeExcelHeader(worksheetIsf, excel_hour_format,headerFormat)
    worksheetBasal.autofilter('A1:C999')
    worksheetIsf.autofilter('A1:C999')
    worksheetBasal.set_column(3, 50, 6) # set columns starting from 3 to width 6
    worksheetIsf.set_column(3, 50, 5) # set columns starting from 3 to width 5
    infoText=['Released under MIT license. See the accompanying LICENSE.txt file for', 'full terms and conditions', '']
    infoText.append('THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR')
    infoText.append('IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,')
    infoText.append('FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE')
    infoText.append('AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER')
    infoText.append('LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,')
    infoText.append('OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN')
    infoText.append('THE SOFTWARE.')
    row=1
    for i in range(len(infoText)):
        worksheetInfo.write_string(row, 1, infoText[i])
        row=row+1
    return (worksheetBasal, worksheetIsf, excel_2decimals_format, excel_integer_format)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Export oref0 autotune files to Microsoft Excel')
    parser.add_argument('-d', '--dir', help='autotune directory', default='.')
    parser.add_argument('-o', '--output', help='default autotune.xlsx', default='autotune.xlsx')
    parser.add_argument('--version', action='version', version='%(prog)s 0.0.2-dev')
    args = parser.parse_args()

    # change to autotune directory
    os.chdir(args.dir)
    
    # Import xlswriter. Do this here, instead of at the top of the file, so that
    # --help will work even if you don't have it.
    try:
        import xlsxwriter
    except:
        print("This software requires XlsxWriter package. Install it with 'sudo pip install XlsxWriter', see http://xlsxwriter.readthedocs.io/")
        sys.exit(1)

    print("Writing headers to Microsoft Excel file %s" % args.output)
    workbook = xlsxwriter.Workbook(args.output)
    (worksheetBasal, worksheetIsf,excel_2decimals_format,excel_integer_format)=excel_init_workbook(workbook)
    row=1 # start on second row, row=0 is for headers
    filenamelist=glob.glob("profile.json")+glob.glob("profile.pump.json")+glob.glob("profile.[0-9].*.json")+glob.glob("profile.[0-9][0-9].*.json")
    for filename in filenamelist:
        f=open(filename, 'r')
        print("Adding %s to Excel" % filename)
        j=json.load(f)
        basalProfile=j['basalprofile']
        isfProfile=j['isfProfile']['sensitivities']
        expandedBasal=expandProfile(basalProfile, 'rate', 'minutes')
        expandedIsf=expandProfile(isfProfile, 'sensitivity', 'offset')
        write_excel_profile(worksheetBasal, row, expandedBasal, excel_2decimals_format)
        write_excel_profile(worksheetIsf, row, expandedIsf, excel_integer_format)
        row=row+1
    workbook.close()  
