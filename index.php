<!doctype html>

<html lang="en">
  <head>
    <!-- Required meta tags -->
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
    
    <!-- Bootstrap CSS -->
    <link rel="stylesheet" href="css/bootstrap.min.css">
    <link rel="stylesheet" href="js/bootstrap-select-1.13.9/dist/css/bootstrap-select.min.css">
    <link rel="stylesheet" href="css/style.css">
    
    <title>Select Image Series</title>
<?php
  $user_name = "local"; /// function checks if visitor is logged.
  echo('<script type="text/javascript"> user_name = "'.$user_name.'"; </script>'."\n");

  $allowed = false;
  echo('<script type="text/javascript"> role = "export"; </script>'."\n");
  $allowed = true;
  $siuid = "";
  if (isset($_GET['siuid'])) {
     $siuid = $_GET['siuid'];
  }
  $pid = "";
  if (isset($_GET['pid'])) {
     $pid = $_GET['pid'];
  }
  echo('<script type="text/javascript"> siuid = "'.$siuid.'"; </script>'."\n");
  echo('<script type="text/javascript"> pid = "'.$pid.'"; </script>'."\n");
?>
  </head>
  <body>
    <?php
      if (isset($_GET['_'])) {
        echo("<script type=\"text/javascript\"> calledQueryID=\"".$_GET['_']."\";</script>");
      }
    ?>

    <header>
  <div class="collapse bg-dark" id="navbarHeader">
    <div class="container-fluid">
      <div class="row">
        <div class="col-sm-8 col-md-7 py-4">
          <h4 class="text-white">About</h4>
	  <p>This module learns from user defined examples what image series to select. This is done in an attempt to save time compared to a manual selection. Studies with well controlled image sequences should be easy to select. Start by selecting a project and wait for the progressbar to load all series. A classification is done automatically every time you select a positive case series (left-click) or a negative case series (Shift+left-click). Keep the number of positive and negative cases balanced. The predicted set of series is displayed after every classification in the right-hand column.</p>
	  <p>Decision tree for the classification is pruned using a 1-standard error rule. The importance values for each measure are displayed in brackets.</p>
<div class="custom-control custom-switch">
  <input type="checkbox" class="custom-control-input" id="allowCachedVersion" checked>
  <label class="custom-control-label" for="allowCachedVersion">Allow usage of cached results (faster loading). If this is disabled, loading a project will be very slow.</label>
</div>
<div class="form-group">
  <button class="btn btn-sm btn-primary" type="button" id="clearSelection"> Start again</button>                                             
  <label for="clearSelection"> Clears the current selection</label>                                                    
</div>                                                                                                                                       
        </div>
        <div class="col-sm-4 offset-md-1 py-4">
          <h4 class="text-white">Contact</h4>
          <ul class="list-unstyled">
            <li><a href="#" class="text-white">Hauke Bartsch</a></li>
          </ul>
	    This module is part of the Steve project - a research information system build for the hospital.	  
        </div>
      </div>
    </div>
  </div>
  <div class="navbar navbar-dark bg-dark shadow-sm">
    <div class="container-fluid d-flex justify-content-between">
      <a href="#" class="navbar-brand d-flex align-items-center">
        <strong>Select image series</strong>
      </a>
      <button class="navbar-toggler" type="button" data-toggle="collapse" data-target="#navbarHeader" aria-controls="navbarHeader" aria-expanded="false" aria-label="Toggle navigation">
        <span class="navbar-toggler-icon"></span>
      </button>
    </div>
  </div>
</header>

    <div class="container-fluid">
      <div class="row">
	<div class="col-md-12" style="margin-top: 20px;">
	<form>
	  <div class="form-group">
	    <label for="project">Project</label>
	    <select class="form-control selectpicker" data-live-search="true" id="project" aria-describedby="projectHelp">
        <option></option>
      </select>
	    <small id="projectHelp" class="form-text text-muted">Select a folder name to start loading data from this location</small>
	  </div>

	</form>
	</div>
      </div>
      <div class="row">
	<div class="col-md-12">
	  <div class="progress" style="margin-bottom: 2px; display: none; position: relative;">
	    <div id="finished" class="finished progress-bar progress-bar-striped progress-bar-animated" role="progressbar" aria-valuenow="50" aria-valuemin="0" aria-valuemax="100" style="width: 50%;"></div>
      <div id="progress-message" style="padding-left: 10px; margin-top: 8px; font-size: 9px; position: absolute;">time to finish, calculating...</div>
    </div>
	</div>
      </div>
      <hr style="border-color: #555;" />
      <div class="row" style="display: none;" id="learning-section">
	<div class="col-md-12">
	  <form>
	    <div class="form-group">
	      <label for="chat">Our learning machine thinks these tags are important <div id="model_nav" style="display: inline-block;"></div></label>
	      <div class="input-group">
		<input type="text" disabled class="form-control" id="chat" title="Variables used for the current classification (pruned CART) by decreasing importance. These variable might not appear in the graph used for classification but instead be used in case that variables from the graph are missing for some cases. In those cases substitute variables listed will replace the missing entries." placeholder="No prediction without training, no training without examples... (love: left-click, hate: Shift+left-click)">
		<div class="input-group-append">
		  <span class="input-group-text" id="processing-time" title="Processing time for the last classification and the accuracy of the pruned model on the training data."></span>
		</div>
	      </div>
	    </div>
	  </form>
        </div>
      </div>
      <div class="row">
	<div class="col-sm-8" style="padding-right: 0px;">
	  <div class="sub-heading-1">
	    <span>Image series by study</span><span class="stats-general"></span>
	  </div>
	</div>
	<div class="col-sm-4">
	  <div class="sub-heading-2">
	    <span>Selected</span><span class="stats"></span>
	    <div class="actions">
	      <button class="btn btn-sm" style="line-height: .5;" title="Download selected image series." data-toggle="modal" data-target="#export-modal">
<svg width="1em" height="1em" viewBox="0 0 16 16" class="bi bi-box-arrow-down" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
  <path fill-rule="evenodd" d="M4.646 11.646a.5.5 0 0 1 .708 0L8 14.293l2.646-2.647a.5.5 0 0 1 .708.708l-3 3a.5.5 0 0 1-.708 0l-3-3a.5.5 0 0 1 0-.708z"/>
  <path fill-rule="evenodd" d="M8 4.5a.5.5 0 0 1 .5.5v9a.5.5 0 0 1-1 0V5a.5.5 0 0 1 .5-.5z"/>
  <path fill-rule="evenodd" d="M2.5 2A1.5 1.5 0 0 1 4 .5h8A1.5 1.5 0 0 1 13.5 2v7a1.5 1.5 0 0 1-1.5 1.5h-1.5a.5.5 0 0 1 0-1H12a.5.5 0 0 0 .5-.5V2a.5.5 0 0 0-.5-.5H4a.5.5 0 0 0-.5.5v7a.5.5 0 0 0 .5.5h1.5a.5.5 0 0 1 0 1H4A1.5 1.5 0 0 1 2.5 9V2z"/>
</svg>
	      </button>
	    </div>
	  </div>
	</div>
      </div>
      <div class="row">
	<div class="col-sm-8">
	  <div id="content" class="row row-cols-3" style="margin-left: 0px;"></div>
        </div>
	<div class="col-sm-4">
	  <div id="content-selected" class="row row-cols-3" style="margin-left: 0px; margin-right: 0px;"></div>
	</div>
      </div>
      <div class="row">
	<div class="col-md-12">
	  <span id="message-text" style="margin-bottom: 30px;"></span>
	</div>
      </div>
      
    </div>


<div class="modal fade" id="tree-modal" tabindex="-1" role="dialog" aria-labelledby="exampleModalLabel" aria-hidden="true">
  <div class="modal-dialog modal-xl" role="document">
    <div class="modal-content">
      <div class="modal-header">
        <h5 class="modal-title" id="exampleModalLabel">Decision Tree</h5>
        <button type="button" class="close" data-dismiss="modal" aria-label="Close">
          <span aria-hidden="true">&times;</span>
        </button>
      </div>
      <div class="modal-body" style="overflow-x: scroll;">
	<p>In the decision tree generated from your labeled data the class 'a' corresponds to the selected image series, 'b' corresponds to the class of undesired series.</p>
        <div id="tree-space"></div>
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
      </div>
    </div>
  </div>
</div>

<div class="modal fade" id="export-modal" tabindex="-1" role="dialog" aria-labelledby="exportModalLabel" aria-hidden="true">
  <div class="modal-dialog modal-xl" role="document">
    <div class="modal-content">
      <div class="modal-header">
        <h5 class="modal-title" id="exampleModalLabel">Export selection</h5>
        <button type="button" class="close" data-dismiss="modal" aria-label="Close">
          <span aria-hidden="true">&times;</span>
        </button>
      </div>
      <div class="modal-body" style="overflow-x: scroll;">
      	<p>The current selection can be exported as a spreadsheet containing a list of StudyInstanceUID and SeriesInstanceUID entries, or as a series of folders that include the raw data. If you want to help make the world a better place donate your model to be used by other users.</p>

<ul class="nav nav-tabs" id="tabContent">
    <li class="nav-item"><a class="nav-link active" href="#spreadsheet" data-toggle="tab">Spreadsheet</a></li>
    <li class="nav-item"><a class="nav-link" href="#data-export" data-toggle="tab">Data export</a></li>
    <li class="nav-item"><a class="nav-link" href="#share-world" data-toggle="tab">Share with the World</a></li>
</ul>

<div class="tab-content" style="background-color: #444; padding: 5px; border: 1px solid #111;">
    <div class="tab-pane active" id="spreadsheet" style="height: 350px;padding-top: 10px;">
      <p>The spreadsheet (CSV format) contains the StudyInstanceUID and SeriesInstanceUID keys for the selected image series. Such information is sufficient to select DICOM files.</p>
      <button class="btn btn-primary download-selected" title="Click here to download a spreadsheet with the StudyInstanceUID and SeriesInstanceUID of your current selection.">Download</button>
    </div>

    <div class="tab-pane" id="data-export"  style="height: 350px; padding-top: 10px;">
        <div class="form-group">
           <label for="export-name" class="control-label">Export folder name</label>
           <input type="text" class="form-control" id="export-name" placeholder="Name your selection (T1, T2, DTI, Fieldmap, Localizer, etc.)"/>
           <small id="exportNameHelp" class="form-text text-muted">Actual folder names are random but a sub-folder will be named with this string.</small>
        </div>
        <button class="btn btn-primary" id="full-export">Full data export</button>
    </div> 
    <div class="tab-pane" id="share-world"  style="height: 350px; padding-top: 10px;">
        <p>The current classification tree can be uploaded to the cloud (requires a working internet connection) so that other users can benefit from your knowledge. Other users can use your model to classify their own data and to discover links between classifications.</p>                                                                                                                                                                                    
        <div class="form-group">
           <label for="handle-name" class="control-label">What is your handle?</label>
           <input type="text" class="form-control" id="handle-name" aria-describedby="handleNameHelp" placeholder="What do you want to be known as?"/>
           <small id="handleNameHelp" class="form-text text-muted">In case we ever establish a reputation this would be helpful.</small>
        </div>
        <div class="form-group">
           <label for="export-name" class="control-label">What did you select?</label>
           <div id="bp_quick_jump"></div>
<script type="text/javascript">
    var BP_ontology_id = "DCM,IOBC";
    var BP_include_definitions = false;
</script>
           <small id="exportNameHelp" class="form-text text-muted">Search selection from David Clunies <a href="https://bioportal.bioontology.org/ontologies/DCM/?p=summary">DCM Ontology</a> and the <a href="https://bioportal.bioontology.org/ontologies/IOBC/">IOBC</a> thanks to BioPortals.</small>
        </div>
        <button class="btn btn-primary" id="share-world-button">Share</button>
    </div> 
</div>

                                                                                                                                                                                          
      <!-- <button class="btn btn-primary" id="share-world" data-dismiss="modal" title="Share your classification model with other users - no data, just the classification tree.">Share</button>
        <button class="btn btn-primary" id="full-export">Full data export</button> -->
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
      </div>
    </div>
  </div>
</div>

<!-- <div class="modal fade" id="modal-share" tabindex="-1" role="dialog" aria-labelledby="modalShare" aria-hidden="true">
  <div class="modal-dialog modal-xl" role="document">
    <div class="modal-content">
      <div class="modal-header">
        <h5 class="modal-title" id="modalShare">Share your knowledge</h5>
        <button type="button" class="close" data-dismiss="modal" aria-label="Close">
          <span aria-hidden="true">&times;</span>
        </button>
      </div>
      <div class="modal-body" style="overflow-x: scroll;">
      	<p>The current classification tree can be uploaded to the cloud. You need internet access to make this work. 
        You will upload your classification tree so that other users can benefit from your selection.</p>
        <div class="form-group">
           <label for="export-name" class="control-label">What did you select?</label>
           <div id="bp_quick_jump"></div>
<script type="text/javascript">
    var BP_ontology_id = "DCM";
</script>
        </div>
        <small id="exportNameHelp" class="form-text text-muted">Search selection from David's <a href=\"https://bioportal.bioontology.org/ontologies/DCM/?p=summary\">DCM Ontology</a> thanks to BioPortals.</small></div>
        <button class="btn btn-primary" id="share-world-button">Share</button>
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
      </div>
    </div>
  </div>
</div> -->

    
    <!-- Optional JavaScript -->
    <!-- jQuery first, then Popper.js, then Bootstrap JS -->
    <script src="js/jquery-3.4.1.min.js"></script>
    <script src="js/jquery-ui.min.js"></script>
    <script src="js/events.js"></script>
    <script src="js/moment.min.js"></script>
    <script src="js/popper.min.js"></script>
    <script src="js/bootstrap.min.js"></script>
    <script src="js/bootstrap-select-1.13.9/dist/js/bootstrap-select.min.js"></script>
    <script src="js/crossdomain_autocomplete.js"></script>
    <script src="js/bioportal_form_complete.js"></script>
    <script src="js/all.js" type="text/javascript"></script>
  </body>
</html>
