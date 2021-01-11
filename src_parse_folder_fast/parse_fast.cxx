/*=========================================================================

  Program: ParseFast

  Copyright (c) 2020 Hauke Bartsch

  For debugging use:
    cmake -DCMAKE_BUILD_TYPE=Release ..
  to build gdcm.
  =========================================================================*/
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
//#include "SHA-256.hpp"
#include "dateprocessing.h"
//#include "gdcmAnonymizer.h"
#include "gdcmAttribute.h"
#include "gdcmCSAHeader.h"
#include "gdcmDefs.h"
#include "gdcmDictPrinter.h"
#include "gdcmDirectory.h"
#include "gdcmGlobal.h"
#include "gdcmImageReader.h"
#include "gdcmPDBHeader.h"
#include "gdcmReader.h"
#include "gdcmStringFilter.h"
#include "gdcmSystem.h"
#include "gdcmWriter.h"
#include "json.hpp"
#include "optionparser.h"
#include <gdcmUIDGenerator.h>
#include <sys/stat.h>

#include <dirent.h>
#include <errno.h>
#include <exception>
#include <regex>
#include <stdexcept>
#include <sys/stat.h>
#include <sys/types.h>

#include "boost/filesystem.hpp"
#include <chrono>
#include <map>
#include <pthread.h>
#include <regex>
#include <stdio.h>
#include <thread>

struct threadparams {
  const char **filenames;
  size_t nfiles;
  char *scalarpointer;
  std::string outputdir;
  bool byseries;
  int thread; // number of the thread
  // each thread will store here the study instance uid (original and mapped)
  std::map<std::string, std::string> byThreadStudyInstanceUID;
  std::map<std::string, std::string> byThreadSeriesInstanceUID;
};

template <typename TPrinter>
static int DoOperation(const std::string &filename, std::stringstream &os, std::string &StudyInstanceUID, std::string &SeriesInstanceUID,
                       std::string &SOPInstanceUID) {
  gdcm::Reader reader;
  reader.SetFileName(filename.c_str());
  bool success = reader.Read();
  if (!success) {
    std::cerr << "Failed to read as DICOM: " << filename << std::endl;
    return 1;
  }
  // get the UIDs from the reader not from the content
  gdcm::DataSet &dss = reader.GetFile().GetDataSet();
  gdcm::File &file = reader.GetFile();
  gdcm::FileMetaInformation &fmi = file.GetHeader();
  std::stringstream strm;
  StudyInstanceUID = "";
  SeriesInstanceUID = "";
  SOPInstanceUID = "";
  bool lookupUIDsInText = false; // we are faster if we get the values from DICOM instead
  // of getting the values from the text using regular expressions (5% of the time required only)
  // This might be different if we would be using a simplier expression.
  if (!lookupUIDsInText) {
    if (dss.FindDataElement(gdcm::Tag(0x0020, 0x000d))) {
      // we need the std::string value for that tag
      strm.str("");
      dss.GetDataElement(gdcm::Tag(0x0020, 0x000d)).GetValue().Print(strm);
      StudyInstanceUID = strm.str();
    } else {
      success = false;
    }
    if (dss.FindDataElement(gdcm::Tag(0x0020, 0x000e))) {
      // we need the std::string value for that tag
      strm.str("");
      dss.GetDataElement(gdcm::Tag(0x0020, 0x000e)).GetValue().Print(strm);
      SeriesInstanceUID = strm.str();
    } else {
      success = false;
    }
    if (dss.FindDataElement(gdcm::Tag(0x0008, 0x0018))) {
      // we need the std::string value for that tag
      strm.str("");
      dss.GetDataElement(gdcm::Tag(0x0008, 0x0018)).GetValue().Print(strm);
      SOPInstanceUID = strm.str();
    } else {
      success = false;
    }
    // fprintf(stdout, "FOUND EARLY: %s %s %s\n", StudyInstanceUID.c_str(), SeriesInstanceUID.c_str(), SOPInstanceUID.c_str());
  }
  int color = 0;
  TPrinter printer;
  printer.SetFile(reader.GetFile());
  printer.SetColor(color != 0);
  printer.Print(os);
  // what are the study instance uid and the series instance uids?
  // "0020", "000d"   (0020,000d) UI [1.3.12.2.1107.5.8.3.484848.578880.49484848.2013070411583314]         # 60,1 Study Instance UID
  //                  (0020,000e) UI [1.3.12.2.1107.5.2.30.26710.2013112908461563759703652.0.0.0]         # 58,1 Series Instance UID
  // "0020", "000e"
  //  std::regex re1("^\\(0020,000d\\) UI \\[([^\\]]*).*", std::regex::awk);
  //  std::regex re2("^\\(0020,000e\\) UI \\[([^\\]]*).*", std::regex::awk);
  if (lookupUIDsInText) {

    std::regex re1("\\(0020,000d\\) UI \\[([A-Z0-9a-z._-]+)");
    std::regex re2("\\(0020,000e\\) UI \\[([A-Z0-9a-z._-]+)");
    std::regex re3("\\(0008,0018\\) UI \\[([A-Z0-9a-z._-]+)");
    std::smatch match;
    std::string content = os.str();
    // fprintf(stdout, "FOUNDFOUNDFOUND: %s", content.c_str());
    if (std::regex_search(content, match, re1) && match.size() > 1) {
      StudyInstanceUID = match.str(1);
    } else {
      success = false;
    }
    if (std::regex_search(content, match, re2) && match.size() > 1) {
      SeriesInstanceUID = match.str(1);
    } else {
      success = false;
    }
    if (std::regex_search(content, match, re3) && match.size() > 1) {
      SOPInstanceUID = match.str(1);
    } else {
      success = false;
    }
  }
  // Only return success when file read succeeded not depending whether or not we printed it
  return success ? 0 : 1;
}

static int PrintPDB(const std::string &filename, bool verbose, std::stringstream &os) {
  (void)verbose;
  gdcm::Reader reader;
  reader.SetFileName(filename.c_str());
  if (!reader.Read()) {
    std::cerr << "Failed to read: " << filename << std::endl;
    return 1;
  }
  gdcm::PDBHeader pdb;
  const gdcm::DataSet &ds = reader.GetFile().GetDataSet();
  const gdcm::PrivateTag &t1 = pdb.GetPDBInfoTag();
  bool found = false;
  int ret = 0;
  if (ds.FindDataElement(t1)) {
    pdb.LoadFromDataElement(ds.GetDataElement(t1));
    pdb.Print(os);
    found = true;
  }
  if (!found) {
    std::cerr << "no pdb tag found" << std::endl;
    ret = 1;
  }
  return ret;
}

static int PrintCSA(const std::string &filename, std::stringstream &os) {
  gdcm::Reader reader;
  reader.SetFileName(filename.c_str());
  if (!reader.Read()) {
    std::cerr << "Failed to read: " << filename << std::endl;
    return 1;
  }
  gdcm::CSAHeader csa;
  const gdcm::DataSet &ds = reader.GetFile().GetDataSet();
  const gdcm::PrivateTag &t1 = csa.GetCSAImageHeaderInfoTag();
  const gdcm::PrivateTag &t2 = csa.GetCSASeriesHeaderInfoTag();
  const gdcm::PrivateTag &t3 = csa.GetCSADataInfo();
  bool found = false;
  int ret = 0;
  if (ds.FindDataElement(t1)) {
    csa.LoadFromDataElement(ds.GetDataElement(t1));
    csa.Print(os);
    found = true;
    if (csa.GetFormat() == gdcm::CSAHeader::ZEROED_OUT) {
      std::cerr << "CSA Header has been zero-out (contains only 0)" << std::endl;
      ret = 1;
    } else if (csa.GetFormat() == gdcm::CSAHeader::DATASET_FORMAT) {
      gdcm::Printer p;
      gdcm::File f;
      f.SetDataSet(csa.GetDataSet());
      p.SetFile(f);
      p.Print(os);
    }
  }
  if (ds.FindDataElement(t2)) {
    csa.LoadFromDataElement(ds.GetDataElement(t2));
    csa.Print(os);
    found = true;
    if (csa.GetFormat() == gdcm::CSAHeader::ZEROED_OUT) {
      std::cerr << "CSA Header has been zero-out (contains only 0)" << std::endl;
      ret = 1;
    } else if (csa.GetFormat() == gdcm::CSAHeader::DATASET_FORMAT) {
      gdcm::Printer p;
      gdcm::File f;
      f.SetDataSet(csa.GetDataSet());
      p.SetFile(f);
      p.Print(os);
    }
  }
  if (ds.FindDataElement(t3)) {
    csa.LoadFromDataElement(ds.GetDataElement(t3));
    csa.Print(os);
    found = true;
    if (csa.GetFormat() == gdcm::CSAHeader::ZEROED_OUT) {
      std::cerr << "CSA Header has been zero-out (contains only 0)" << std::endl;
      ret = 1;
    } else if (csa.GetFormat() == gdcm::CSAHeader::INTERFILE) {
      const char *interfile = csa.GetInterfile();
      if (interfile)
        os << interfile << std::endl;
    } else if (csa.GetFormat() == gdcm::CSAHeader::DATASET_FORMAT) {
      gdcm::Printer p;
      gdcm::File f;
      f.SetDataSet(csa.GetDataSet());
      p.SetFile(f);
      p.Print(os);
    }
  }
  if (!found) {
    std::cerr << "no csa tag found" << std::endl;
    ret = 1;
  }
  return ret;
}

void *ReadFilesThread(void *voidparams) {
  threadparams *params = static_cast<threadparams *>(voidparams);

  int res = 0;
  const size_t nfiles = params->nfiles;
  for (unsigned int file = 0; file < nfiles; ++file) {
    const char *filename = params->filenames[file];

    std::stringstream os;
    std::string StudyInstanceUID;
    std::string SeriesInstanceUID;
    std::string SOPInstanceUID;
    // get the header and StudyInstance and SeriesInstanceUIDs from the file
    res = DoOperation<gdcm::Printer>(filename, os, StudyInstanceUID, SeriesInstanceUID, SOPInstanceUID);
    if (res == 1) {
      // failed to read this file, skip now
      continue;
    }
    // fprintf(stdout, "StudyInstanceUID is : %s\n", StudyInstanceUID.c_str());
    // fprintf(stdout, "SeriesInstanceUID is : %s\n", SeriesInstanceUID.c_str());
    // fprintf(stdout, "SOPInstanceUID is : %s\n", SOPInstanceUID.c_str());
    // res += PrintCSA(filename, os);
    // res += PrintPDB(filename, false, os);
    // std::cout << os.str() << std::endl;

    // write the header to a cache text file
    std::string filenamestring = SeriesInstanceUID;
    std::string seriesdirname = StudyInstanceUID; // only used if byseries is true
    std::string sopinstanceuid = SOPInstanceUID;

    // std::string fn = params->outputdir + "/" + filenamestring + ".cache";
    // use the series instance uid as a directory name
    std::string dn = params->outputdir + "/" + seriesdirname;
    struct stat buffer;
    if (!(stat(dn.c_str(), &buffer) == 0)) {
      // DIR *dir = opendir(dn.c_str());
      // if ( ENOENT == errno)	{
      mkdir(dn.c_str(), 0777);
    }
    // create the folders for the symbolic links as well
    dn = params->outputdir + "/" + seriesdirname + "/" + filenamestring;
    if (!(stat(dn.c_str(), &buffer) == 0)) {
      // DIR *dir = opendir(dn.c_str());
      // if ( ENOENT == errno)	{
      mkdir(dn.c_str(), 0777);
    }
    // create the symbolic links
    std::string fn = params->outputdir + "/" + seriesdirname + "/" + filenamestring + "/" + SOPInstanceUID;
    symlink(filename, fn.c_str());

    fn = params->outputdir + "/" + seriesdirname + "/" + filenamestring + ".cache";
    // if the cache exists already, don't write again
    struct stat stat_buffer;
    if (stat(fn.c_str(), &stat_buffer) == 0) {
      fprintf(stdout, "[%d] write to cache file: %s\n", params->thread, fn.c_str());
      std::string outfilename(fn);
      std::ofstream outFile;
      outFile.open(outfilename);
      outFile << os.rdbuf();
      outFile.close();
    }

    // save the file again to the output
    // create a symbolic link instead of writing again
    /*gdcm::Writer writer;
    writer.SetFile(fileToAnon);
    writer.SetFileName(outfilename.c_str());
    try {
      if (!writer.Write()) {
        fprintf(stderr, "Error [#file: %d, thread: %d] writing file \"%s\" to \"%s\".\n", file, params->thread, filename, outfilename.c_str());
      }
    } catch (const std::exception &ex) {
      std::cout << "Caught exception \"" << ex.what() << "\"\n";
    }*/
  }
  return voidparams;
}

void ShowFilenames(const threadparams &params) {
  std::cout << "start" << std::endl;
  for (unsigned int i = 0; i < params.nfiles; ++i) {
    const char *filename = params.filenames[i];
    std::cout << filename << std::endl;
  }
  std::cout << "end" << std::endl;
}

void ReadFiles(size_t nfiles, const char *filenames[], const char *outputdir, bool byseries, int numthreads, std::string storeMappingAsJSON) {
  // \precondition: nfiles > 0
  assert(nfiles > 0);

  // lets change the DICOM dictionary and add some private tags - this is still not sufficient to be able to write the private tags
  gdcm::Global gl;
  if (gl.GetDicts().GetPrivateDict().FindDictEntry(gdcm::Tag(0x0013, 0x0010))) {
    gl.GetDicts().GetPrivateDict().RemoveDictEntry(gdcm::Tag(0x0013, 0x0010));
  }
  gl.GetDicts().GetPrivateDict().AddDictEntry(gdcm::Tag(0x0013, 0x0010),
                                              gdcm::DictEntry("Private Creator Group CTP-LIKE", "0x0013, 0x0010", gdcm::VR::LO, gdcm::VM::VM1));

  if (gl.GetDicts().GetPrivateDict().FindDictEntry(gdcm::Tag(0x0013, 0x1010))) {
    gl.GetDicts().GetPrivateDict().RemoveDictEntry(gdcm::Tag(0x0013, 0x1010));
  }
  gl.GetDicts().GetPrivateDict().AddDictEntry(gdcm::Tag(0x0013, 0x1010), gdcm::DictEntry("ProjectName", "0x0013, 0x1010", gdcm::VR::LO, gdcm::VM::VM1));

  if (gl.GetDicts().GetPrivateDict().FindDictEntry(gdcm::Tag(0x0013, 0x1013))) {
    gl.GetDicts().GetPrivateDict().RemoveDictEntry(gdcm::Tag(0x0013, 0x1013));
  }
  gl.GetDicts().GetPrivateDict().AddDictEntry(gdcm::Tag(0x0013, 0x1013), gdcm::DictEntry("SiteID", "0x0013, 0x1013", gdcm::VR::LO, gdcm::VM::VM1));

  if (gl.GetDicts().GetPrivateDict().FindDictEntry(gdcm::Tag(0x0013, 0x1012))) {
    gl.GetDicts().GetPrivateDict().RemoveDictEntry(gdcm::Tag(0x0013, 0x1012));
  }
  gl.GetDicts().GetPrivateDict().AddDictEntry(gdcm::Tag(0x0013, 0x1012), gdcm::DictEntry("SiteName", "0x0013, 0x1012", gdcm::VR::LO, gdcm::VM::VM1));

  /*  const char *reference = filenames[0]; // take the first image as reference

    gdcm::ImageReader reader;
    reader.SetFileName(reference);
    if (!reader.Read()) {
      // That would be very bad...
      assert(0);
    }

    const gdcm::Image &image = reader.GetImage();
    gdcm::PixelFormat pixeltype = image.GetPixelFormat();
    unsigned long len = image.GetBufferLength();
    const unsigned int *dims = image.GetDimensions();
    unsigned short pixelsize = pixeltype.GetPixelSize();
    (void)pixelsize;
    assert(image.GetNumberOfDimensions() == 2); */
  if (nfiles <= numthreads) {
    numthreads = 1; // fallback if we don't have enough files to process
  }
  if (numthreads == 0) {
    numthreads = 1;
  }

  const unsigned int nthreads = numthreads; // how many do we want to use?
  threadparams params[nthreads];

  pthread_t *pthread = new pthread_t[nthreads];

  // There is nfiles, and nThreads
  assert(nfiles >= nthreads);
  const size_t partition = nfiles / nthreads;
  for (unsigned int thread = 0; thread < nthreads; ++thread) {
    params[thread].filenames = filenames + thread * partition;
    params[thread].outputdir = outputdir;
    params[thread].nfiles = partition;
    params[thread].byseries = byseries;
    params[thread].thread = thread;
    if (thread == nthreads - 1) {
      // There is slightly more files to process in this thread:
      params[thread].nfiles += nfiles % nthreads;
    }
    assert(thread * partition < nfiles);
    int res = pthread_create(&pthread[thread], NULL, ReadFilesThread, &params[thread]);
    if (res) {
      std::cerr << "Unable to start a new thread, pthread returned: " << res << std::endl;
      assert(0);
    }
  }
  // DEBUG
  size_t total = 0;
  for (unsigned int thread = 0; thread < nthreads; ++thread) {
    total += params[thread].nfiles;
  }
  assert(total == nfiles);
  // END DEBUG

  for (unsigned int thread = 0; thread < nthreads; thread++) {
    pthread_join(pthread[thread], NULL);
  }

  // we can access the per thread storage of study instance uid mappings now
  if (storeMappingAsJSON.length() > 0) {
    std::map<std::string, std::string> uidmappings1;
    std::map<std::string, std::string> uidmappings2;
    for (unsigned int thread = 0; thread < nthreads; thread++) {
      for (std::map<std::string, std::string>::iterator it = params[thread].byThreadStudyInstanceUID.begin();
           it != params[thread].byThreadStudyInstanceUID.end(); ++it) {
        uidmappings1.insert(std::pair<std::string, std::string>(it->first, it->second));
      }
    }
    for (unsigned int thread = 0; thread < nthreads; thread++) {
      for (std::map<std::string, std::string>::iterator it = params[thread].byThreadSeriesInstanceUID.begin();
           it != params[thread].byThreadSeriesInstanceUID.end(); ++it) {
        uidmappings2.insert(std::pair<std::string, std::string>(it->first, it->second));
      }
    }
    nlohmann::json ar;
    ar["StudyInstanceUID"] = {};
    ar["SeriesInstanceUID"] = {};
    for (std::map<std::string, std::string>::iterator it = uidmappings1.begin(); it != uidmappings1.end(); ++it) {
      ar["StudyInstanceUID"][it->first] = it->second;
    }
    for (std::map<std::string, std::string>::iterator it = uidmappings2.begin(); it != uidmappings2.end(); ++it) {
      ar["SeriesInstanceUID"][it->first] = it->second;
    }

    std::ofstream jsonfile(storeMappingAsJSON);
    if (!jsonfile.is_open()) {
      fprintf(stderr, "Failed to open file \"%s\"", storeMappingAsJSON.c_str());
    } else {
      jsonfile << ar;
      jsonfile.flush();
      jsonfile.close();
    }
  }

  delete[] pthread;
}

struct Arg : public option::Arg {
  static option::ArgStatus Required(const option::Option &option, bool) { return option.arg == 0 ? option::ARG_ILLEGAL : option::ARG_OK; }
  static option::ArgStatus Empty(const option::Option &option, bool) { return (option.arg == 0 || option.arg[0] == 0) ? option::ARG_OK : option::ARG_IGNORE; }
};

enum optionIndex { UNKNOWN, HELP, INPUT, OUTPUT, NUMTHREADS, TAGCHANGE };
const option::Descriptor usage[] = {{UNKNOWN, 0, "", "", option::Arg::None,
                                     "USAGE: ParseFast [options]\n\n"
                                     "Options:"},
                                    {HELP, 0, "", "help", Arg::None,
                                     "  --help  \tParse DICOM files and create output folders. Read DICOM image files and write "
                                     "out a cached version of the files."},
                                    {INPUT, 0, "i", "input", Arg::Required, "  --input, -i  \tInput directory."},
                                    {OUTPUT, 0, "o", "output", Arg::Required, "  --output, -o  \tOutput directory."},
                                    {NUMTHREADS, 0, "t", "numthreads", Arg::Required, "  --numthreads, -t  \tHow many threads should be used (default 4)."},
                                    {UNKNOWN, 0, "", "", Arg::None,
                                     "\nExamples:\n"
                                     "  ParseFast --input directory --output directory -b\n"
                                     "  ParseFast --help\n"},
                                    {0, 0, 0, 0, 0, 0}};

std::vector<std::string> listFilesSTD(const std::string &path) {
  std::vector<std::string> files;
  for (boost::filesystem::recursive_directory_iterator end, dir(path); dir != end; ++dir) {
    // std::cout << *dir << "\n";  // full path
    if (is_regular_file(dir->path())) {
      files.push_back(dir->path().c_str());
      if ((files.size() % 200) == 0) {
        fprintf(stdout, "[reading files %05lu]\r", files.size());
      }
    }
  }
  fprintf(stdout, "[reading files %05lu done]\r", files.size());

  return files;
}

int main(int argc, char *argv[]) {

  argc -= (argc > 0);
  argv += (argc > 0); // skip program name argv[0] if present

  option::Stats stats(usage, argc, argv);
  std::vector<option::Option> options(stats.options_max);
  std::vector<option::Option> buffer(stats.buffer_max);
  option::Parser parse(usage, argc, argv, &options[0], &buffer[0]);

  if (parse.error())
    return 1;

  if (options[HELP] || argc == 0) {
    option::printUsage(std::cout, usage);
    return 0;
  }

  for (option::Option *opt = options[UNKNOWN]; opt; opt = opt->next())
    std::cout << "Unknown option: " << std::string(opt->name, opt->namelen) << "\n";

  std::string input;
  std::string output;
  std::string exportanonfilename = ""; // anon.json
  bool byseries = true;
  int numthreads = 4;
  std::string projectname = "";
  std::string storeMappingAsJSON = "";
  for (int i = 0; i < parse.optionsCount(); ++i) {
    option::Option &opt = buffer[i];
    // fprintf(stdout, "Argument #%d is ", i);
    switch (opt.index()) {
    case HELP:
      // not possible, because handled further above and exits the program
    case INPUT:
      if (opt.arg) {
        // fprintf(stdout, "--input '%s'\n", opt.arg);
        input = opt.arg;
      } else {
        fprintf(stdout, "--input needs a directory specified\n");
        exit(-1);
      }
      break;
    case OUTPUT:
      if (opt.arg) {
        // fprintf(stdout, "--output '%s'\n", opt.arg);
        output = opt.arg;
      } else {
        fprintf(stdout, "--output needs a directory specified\n");
        exit(-1);
      }
      break;
    case NUMTHREADS:
      if (opt.arg) {
        // fprintf(stdout, "--numthreads %d\n", atoi(opt.arg));
        numthreads = atoi(opt.arg);
      } else {
        fprintf(stdout, "--numthreads needs an integer specified\n");
        exit(-1);
      }
      break;
    case UNKNOWN:
      // not possible because Arg::Unknown returns ARG_ILLEGAL
      // which aborts the parse with an error
      break;
    }
  }

  // Check if user pass in a single directory
  if (gdcm::System::FileIsDirectory(input.c_str())) {
    std::vector<std::string> files;
    files = listFilesSTD(input.c_str());
    fprintf(stdout, "reading files done\n");

    const size_t nfiles = files.size();
    const char **filenames = new const char *[nfiles];
    for (unsigned int i = 0; i < nfiles; ++i) {
      filenames[i] = files[i].c_str();
    }
    if (storeMappingAsJSON.length() > 0) {
      storeMappingAsJSON = output + std::string("/") + storeMappingAsJSON;
    }
    if (nfiles == 0) {
      fprintf(stderr, "No files found.\n");
      fflush(stderr);
      exit(-1);
    }

    // ReadFiles(nfiles, filenames, output.c_str(), numthreads, confidence, storeMappingAsJSON);
    ReadFiles(nfiles, filenames, output.c_str(), byseries, numthreads, storeMappingAsJSON);
    delete[] filenames;
  } else {
    // its a single file, process that
    // but is it a single file???? Could be a directory that not exists
    if (!gdcm::System::FileExists(input.c_str())) {
      fprintf(stderr, "File or directory does not exist (%s).\n", input.c_str());
      fflush(stderr);
      exit(-1);
    }

    const char **filenames = new const char *[1];
    filenames[0] = input.c_str();
    // ReadFiles(1, filenames, output.c_str(), 1, confidence, storeMappingAsJSON);
    ReadFiles(1, filenames, output.c_str(), byseries, numthreads, storeMappingAsJSON);
  }

  return 0;
}
