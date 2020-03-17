#!/usr/bin/env python3

from string import Template

class AutoHeader (object) :
    def __init__(self, input_file_name, output_file_name):
        self.input_file_name = input_file_name
        self.output_file_name = output_file_name

    def generate_header(self, **kwds) :
        try:
            getattr(self, "input_file")
            getattr(self, "output_file")
        except AttributeError:
            raise ValueError("Cannot find file handle")

        template = Template(self.input_file.read())
        self.output_file.write(template.substitute(**kwds))

    def __enter__(self):
        self.input_file = open(self.input_file_name, 'r')
        self.output_file = open(self.output_file_name, 'w')
        return(self)

    def __exit__(self, type, value, traceback):
        self.input_file.close()
        self.output_file.close()
        del self.input_file
        del self.output_file

if __name__ == "__main__" :
    import argparse
    import re
    import os

    parser = argparse.ArgumentParser(description='Template parser using environement variable as keys')

    parser.add_argument('--input_file', 
                        nargs='+',
                        help='specify a Template file',
                        required=True)
    
    parser.add_argument('--output_dir', 
                        nargs=1,
                        help='specify output directory',
                        required=True)

    args = parser.parse_args()

    templateFileNamePattern = re.compile(r".+\.h\.in")

    for template_file in args.input_file :
        # check file name format 
        if(templateFileNamePattern.match(template_file) is None) :
            raise ValueError (f"{template_file} doesn't match *.h.in pattern")

        # remove .in and path 
        output_file = os.path.splitext(os.path.basename(template_file))[0]
        
        output_file = os.path.join(args.output_dir[0], output_file)

        with AutoHeader(template_file, output_file) as config_header:
            config_header.generate_header(**os.environ)
