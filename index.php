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
  session_start(); /// initialize session
  include("../../php/AC.php");
  $user_name = check_logged(); /// function checks if visitor is logged.
  echo('<script type="text/javascript"> user_name = "'.$user_name.'"; </script>'."\n");

  $allowed = false;
  if (check_permission( "Export" )) {
     echo('<script type="text/javascript"> role = "export"; </script>'."\n");
     $allowed = true;
  }
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
  <label class="custom-control-label" for="allowCachedVersion">Allow usage of cached results (faster loading)</label>
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
	    <select class="form-control selectpicker" data-live-search="true" id="project" aria-describedby="projectHelp"></select>
	    <small id="projectHelp" class="form-text text-muted">Select the project name to start loading data</small>
	  </div>

	</form>
	</div>
      </div>
      <div class="row">
	<div class="col-md-12">
	  <div class="progress" style="margin-bottom: 2px; display: none;">
	    <div id="finished" class="finished progress-bar progress-bar-striped progress-bar-animated" role="progressbar" aria-valuenow="50" aria-valuemin="0" aria-valuemax="100" style="width: 50%;"></div>
	  </div>
	</div>
      </div>
      <hr style="border-color: #555;" />
      <div class="row" style="display: none;" id="learning-section">
	<div class="col-md-12">
	  <form>
	    <div class="form-group">
	      <label for="chat">Our learning machine thinks these tags are important</label>
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
	      <button class="btn btn-sm" style="line-height: .5;" id="download-selected" title="Download selected image series information as a spreadsheet.">
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

    
    <!-- Optional JavaScript -->
    <!-- jQuery first, then Popper.js, then Bootstrap JS -->
    <script src="js/jquery-3.4.1.min.js"></script>
    <script src="js/jquery-ui.min.js"></script>
    <script src="js/events.js"></script>    
    <script src="js/popper.min.js"></script>
    <script src="js/bootstrap.min.js"></script>
    <script src="js/bootstrap-select-1.13.9/dist/js/bootstrap-select.min.js"></script>
    <script src="js/all.js" type="text/javascript"></script>
  </body>
</html>
