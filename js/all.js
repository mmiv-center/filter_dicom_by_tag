function populateStudyInstanceUIDs() {
	// pull the list of projects for the current user
	jQuery.getJSON('php/getProjects.php', function(data) {
		jQuery('#project').children().remove();
		jQuery('#project').append("<option></option>"); // add default
	    	for (var i = 0; i < data.length; i++) {
			jQuery("#project").append("<option value=\"" + data[i]['record_id'] + "\">" + data[i]['record_id'] + "</option>");
		}
		jQuery('select').selectpicker('refresh');
	});
}

var dataCache = {}; // a dictionary with StudyInstanceUID and SeriesInstanceUID and Strings
function appendSeries(StudyInstanceUID, SeriesInstanceUID, data) {
	var escapedStudyInstanceUID = StudyInstanceUID.replace(/\./g, "\\.");
	var escapedSeriesInstanceUID = SeriesInstanceUID.replace(/\./g, "\\.");

	// do something
	var entry = jQuery('#content #' + escapedStudyInstanceUID);
	if (!entry.length > 0) {
		jQuery('#content').append("<div class='Study' id='" + StudyInstanceUID + "'><div class='bottom-back'><span></span></div><div class='bottom-back-event'><span></span></div></div>");
		jQuery('#content-selected').append("<div class='Study' id='" + StudyInstanceUID + "-s'></div>");
		// image series to appear before we can fix the alignment
	}
	//var entry2 = jQuery('#content-selected #' + StudyInstanceUID + "-s");
	//if (!entry2.length > 0) {
	//}

	var text_node = document.createTextNode(data);
	var dd = parseDICOMStruct(jQuery(text_node).text());

	// lets cache the values instead of adding them to the DOM
	if (typeof dataCache[StudyInstanceUID] === 'undefined')
		dataCache[StudyInstanceUID] = {};
	dataCache[StudyInstanceUID][SeriesInstanceUID] = dd;

	var ReferringPhysician = "";
	if (typeof dd['0008'] !== 'undefined' && typeof dd['0008']['0090'] !== 'undefined') {
		ReferringPhysician = dd['0008']['0090'];
		jQuery('#' + escapedStudyInstanceUID).find('div.bottom-back-event span').text(dd['0008']['0090']);
	}

	var PatientName = "";
	if (typeof dd['0010'] !== 'undefined' && typeof dd['0010']['0010'] !== 'undefined') {
		jQuery('#' + escapedStudyInstanceUID).find('div.bottom-back span').text(dd['0010']['0010']);
		PatientName = dd['0010']['0010'];
	}
	if (PatientName == "") {
		// if we don't have a patient name use patient ID
		if (typeof dd['0010'] !== 'undefined' && typeof dd['0010']['0020'] !== 'undefined') {
			jQuery('#' + escapedStudyInstanceUID).find('div.bottom-back span').text(dd['0010']['0020']);
		}
	}

	var SeriesNumber = "";
	if (typeof dd['0020'] !== 'undefined' && typeof dd['0020']['0011'] !== 'undefined')
		SeriesNumber = dd['0020']['0011'];

	var modality = "--";
	if (typeof dd['0008'] !== 'undefined' && typeof dd['0008']['0060'] !== 'undefined')
		modality = dd['0008']['0060'];

	var numImages = "--";
	if (typeof dd['0020'] !== 'undefined' && typeof dd['0020']['1209'] !== 'undefined')
		numImages = dd['0020']['1209'];

	var SeriesDescription = "";
	if (typeof dd['0008'] !== 'undefined' && typeof dd['0008']['103e'] !== 'undefined')
		SeriesDescription = dd['0008']['103e'];

	// We should add the series based on the SeriesNumber to get the sorting right
	var t = '<div class="Series" id="' + SeriesInstanceUID + '" title="Mouse-click to see full tags in console">' +
		'<div class="modality">' + modality + '</div>' +
		'<div class="numImages">' + numImages + '</div>' +
		'<div class="SeriesNumber">' + SeriesNumber + '</div>' +
		'<div class="SeriesDescription">' + SeriesDescription + '</div>' +
		'<img src="" /></div>';
	var els = jQuery('#' + escapedStudyInstanceUID).find('div.Series');
	if (els.length == 0) {
		jQuery('#' + escapedStudyInstanceUID).append(t);
	} else {
		var inserted = false;
		for (var i = 0; i < els.length; i++) {
			var sn = jQuery(els[i]).find("div.SeriesNumber").text();
			if (parseInt(SeriesNumber) < parseInt(sn)) {
				jQuery(t).insertBefore(jQuery(els[i]));
				inserted = true;
				break;
			}
		}
		if (!inserted) {
			jQuery('#' + escapedStudyInstanceUID).append(t);
		}
	}
	/*    jQuery('#' + StudyInstanceUID).append('<div class="Series" id="' + SeriesInstanceUID + '" data="' + jQuery(text_node).text() + '" title="Mouse-click to see full tags in console">' +
						  '<div class="modality">' + modality + '</div>' +
						  '<div class="numImages">' + numImages + '</div>' +
						  '<div class="SeriesNumber">' + SeriesNumber + '</div>' +
						  '<div class="SeriesDescription">' + SeriesDescription + '</div>' +
						  '<img src="" /></div>');
	*/

	//jQuery('#' + StudyInstanceUID + '-s').append('<div class="Series" id="' + SeriesInstanceUID + '-s" data="' + jQuery(text_node).text() + '" title="' + jQuery(text_node).text() + '"></div>');
	//alignRight(); // this will not work for the last of the fields... there we need to wait for all the
}

function parseDICOMStruct(txt) {
	var r = {};
	// build a structure by reading the DICOM information line by line
	if (typeof txt === 'undefined' || txt == null) {
		return r;
	}
	var ar = txt.split("\n");
	for (line in ar) {
		//console.log("line is: " + ar[line]);
		const regex = /.*\(([0-9a-f]+),([0-9a-f]+)\) [A-Z][A-Z] \[([^\]]*)\].*/;
		const found = ar[line].match(regex);
		if (typeof found !== 'undefined' && found !== null && found.length > 2) {
			//console.log("found tag " + found[1] + "," + found[2] + " with value: " + found[3]);
			if (typeof r[found[1]] === 'undefined') {
				r[found[1]] = {};
			}
			r[found[1]][found[2]] = found[3];
		}
	}
	return r;
}

function pad(num, size) {
	num = num.toString();
	while (num.length < size) num = "0" + num;
	return num;
}

// keep the models from the last run around
models_last_run = [];
current_model = -1;

function nextModel() {
	current_model++;
	if (current_model > models_last_run.length - 1)
		current_model = 0;
	if (current_model < 0)
		current_model = models_last_run.length - 1;
	updateModel(current_model);
}

function previousModel() {
	current_model--;
	if (current_model > models_last_run.length - 1)
		current_model = 0;
	if (current_model < 0)
		current_model = models_last_run.length - 1;
	updateModel(current_model);
}

function updateModel(current_model) {
	jQuery('#model_nav').children().remove();
	jQuery('#model_nav').append("<div>(" + pad((current_model + 1), 2) + "/" + models_last_run.length + " models, <a href='#' onclick='nextModel();'>next</a> <a href='#' onclick='previousModel();'>previous</a>)</div>");

	var data = models_last_run[current_model];
	// remove again in case we have more than one mouse-click
	// TODO: Any way to cancel the previous iteration? Delayed execution?
	jQuery('#content-selected div.Series').remove();
	jQuery('#content div.Series.a').removeClass('a');
	jQuery('#content div.Series.b').removeClass('b');
	jQuery('#share-world-button').attr('model-names', JSON.stringify(data['model_binary']));
	
	console.log("Got some data back from the model: " + JSON.stringify(data));
	jQuery('#processing-time').text(data['processing_time'].toFixed(2) + "sec, training acc. = " + data['accuracy_percent'].toFixed(0) + "%");
	if (typeof data['tree_image'] !== 'undefined') {
		jQuery('#tree-space').children().remove();
		jQuery('#tree-space').append("<img style='width: 100%;' src='php/data/" + data['tree_image'] + "'/>");
		jQuery('#tree-space').append("<div><center>" + data['rules'] + "</center></div>");
	}
	// lets highlight the class for each
	// lets reset all series first (remove a, b classes)
	jQuery('#content div.a').removeClass('a');
	jQuery('#content div.b').removeClass('b');
	for (var i = 0; i < data.class.length; i++) {
		var st = data.study[i];
		var se = "div#" + data.series[i];
		var c = data.class[i];
		jQuery(se.replace(/\./g, "\\.")).removeClass('a').removeClass('b').addClass(c);
	}
	if (typeof data['splits'] == 'string') {
		data['splits'] = [data['splits']];
	}
	if (typeof data['splits'] !== 'undefined') {
		var elems = data['splits'];
		var erg = "";
		for (var i = 0; i < elems.length; i++) {
			var elem = elems[i];
			var el = elem.replace(/^g/, "").replace(".", "").toUpperCase();
			var nam = "";
			if (typeof dicom_dict[el] !== 'undefined') {
				nam = dicom_dict[el];
			} else {
				nam = elem;
			}
			// what is the importance?
			var weight = "";
			if (data['splits_weight'].length > i) {
				weight = " (" + Number.parseFloat(data['splits_weight'][i]).toFixed(2) + ")";
			}
			if (i < elems.length - 1) {
				erg = erg + nam + weight + ", ";
			} else {
				erg = erg + nam + weight;
			}
		}
		var erg2 = "";
		if (typeof data['treevars'] === 'string') {
			data['treevars'] = [data['treevars']];
		}
		for (var i = 0; i < data['treevars'].length; i++) {
			var elem = data['treevars'][i];
			var el = elem.replace(/^g/, "").replace(".", "").toUpperCase();
			var nam = "";
			if (typeof dicom_dict[el] !== 'undefined') {
				nam = dicom_dict[el];
			} else {
				nam = elem;
			}
			if (i < data['treevars'].length - 1) {
				erg2 = erg2 + nam + ", ";
			} else {
				erg2 = erg2 + nam;
			}
		}
		jQuery('#chat').val(erg2 + "; replacement if missing: " + erg);
		jQuery('#chat').effect('highlight');
		
	} else
	jQuery('#chat').val("no splits found for this run...");
	// now map all the found series to content-selected
	//jQuery('#content-selected').find('div.Series').remove();	
	jQuery('#content div.a,div.highlighted-human-a').each(function(a, b) {
		var study = jQuery(b).parent().attr('id');
		var series = jQuery(b).attr('id');
		var escapedstudy = study.replace(/\./g, "\\.");
		var escapedseries = series.replace(/\./g, "\\.");
		jQuery('#content-selected').find('div#' + escapedstudy + "-s").append('<div class="Series" id="' + series + '-s">' +
		'<div class="modality">' + jQuery(b).find('div.modality').text() + '</div>' +
		'<div class="numImages">' + jQuery(b).find('div.numImages').text() + '</div>' +
		'<div class="SeriesNumber">' + jQuery(b).find('div.SeriesNumber').text() + '</div>' +
		'<div class="SeriesDescription">' + jQuery(b).find('div.SeriesDescription').text() + '</div>' +
		'<img src="' + jQuery(b).find('img').attr('src') + '" style="margin-left: ' + jQuery(b).find('img').css('margin-left') + '; margin-top: ' + jQuery(b).find('img').css('margin-top') + ';"/>' +
		'</div>');
	});
	var numParticipants = [...new Set(jQuery.map(jQuery('#content div.bottom-back span'), function(a, i) {
		return jQuery(a).text();
	}))].length;
	var numSelectedStudies = 0;
	jQuery.map(jQuery('#content-selected div.Study'), function(value, i) {
		if (jQuery(value).find('div.Series').length > 0)
		numSelectedStudies++;
	});
	jQuery('span.stats-general').text(" (" + numParticipants + " participant" + (numParticipants > 1 ? "s" : "") + ", " +
	jQuery('#content div.Series').length + " imaging series in " +
	jQuery('#content div.Study').length + " imaging stud" + (jQuery('#content div.Study').length > 1 ? "ies" : "y") + ")");
	jQuery('span.stats').text(" " + jQuery('#content-selected div.Series').length + " series in " + numSelectedStudies + " stud" + (numSelectedStudies > 1 ? "ies" : "y") + "");
	//jQuery('#message-text').text("Classification of " + data['class'].length + " image series resulted in " + jQuery('#content div.a').length + " matches.");
}

// classify
function sendToClassifier() {
	// ok, we need the structure for all found entries and we need to add the classification
	// by study - so we need to select all that we have and classify all that we need in other
	// series
	var data = {
		"train": [],
		"predict": []
	}; // we will need training and prediction (request prediction back - one-shot learning)

	jQuery('#content').find('div.Series').each(function(a, b) {
		var type = "unknown";
		if (jQuery(b).hasClass('highlighted-human-a') || jQuery(b).hasClass('highlighted-human-b')) {
			// needs to go into training set - positive negative examples
			if (jQuery(b).hasClass('highlighted-human-a'))
				type = "a";
			else
				type = "b";
		}
		var studyinstanceuid = jQuery(this).parent().attr('id');
		var seriesinstanceuid = jQuery(this).attr('id');
		if (type != "unknown") {
			data['train'].push({
				class: type,
				study: studyinstanceuid,
				series: seriesinstanceuid,
				data: dataCache[studyinstanceuid][seriesinstanceuid]
			});
		} else {
			data['predict'].push({
				study: studyinstanceuid,
				series: seriesinstanceuid,
				data: dataCache[studyinstanceuid][seriesinstanceuid]
			});
		}
	});
	// before we send the query out we should remove our current results
	jQuery('#content-selected div.Series').remove();
	jQuery('#content div.Series.a').removeClass('a');
	jQuery('#content div.Series.b').removeClass('b');

	// call the server prediction
	// TODO: we should only allow the last classification to continue
	jQuery.post('php/ai01.php', {
		data: JSON.stringify(data)
	},
	function(data) {
		models_last_run = data;
		current_model = 0; // set this in the interface
		updateModel(current_model);
	}, "json").fail(function() {
		console.log("we did not get something back ... ");
		alert("Error: There seems to be a problem with running the statistical analysis, please contact the developer.");
	});
	
}

function addThumbnails() {
	jQuery.get('php/data/' + lastQueryID + '/imageIndex.txt', function(data) {
		// the order in this file indicates the order of images in the montage
		var l = data.split("\n").map(function(a) {
			return a.split("/").pop().replace(".png", "");
		});
		var imageURL = "/php/data/" + lastQueryID + "/imageMontage.jpg?_=" + Math.random();
		l.forEach(function(value, idx) {
			if (value.length > 0) {
				// given the idx what is the image we look for?
				// each image has a with of 60 * 32 (image size is 32x32)
				// given the idx value we end up with a location in the image of
				// top left corner for this image is:
				var y = Math.floor(idx / 60);
				var x = idx - (y * 60);
				var escapedvalue = value.replace(/\./g, "\\.");
				jQuery('#series_' + escapedvalue + ' img').attr('src', imageURL);
				jQuery('#series_' + escapedvalue + ' img').css('margin-left', -x * 32);
				jQuery('#series_' + escapedvalue + ' img').css('margin-top', -y * 32);
				//jQuery('#series_'+value+' img').attr('bla', idx);
			}
		});
	});
}

// see if we have an update on this query
function checkQueryID() {
	jQuery('#learning-section').show();
	jQuery('div.progress').show();

	jQuery.getJSON('php/queryID.php', {
		'ID': lastQueryID
	}, function(data) {
		var howmany = jQuery('#results').children().length; // how many series
		jQuery('#content').show();
		// tables can be large, we should only add new rows, so no remove first
		jQuery('#content').children().remove();
		jQuery('#content-selected').children().remove();
		var table_counter = 1; // if we find a new row insert, else keep
		// add all rows at once (small speed up)
		var rowstxt = "";
		for (var i = 0; i < Object.keys(data).length; i++) {
			var key = Object.keys(data)[i];
			for (var j = 0; j < Object.keys(data[key]).length; j++) {
				var key2 = Object.keys(data[key])[j];
				appendSeries('study_' + key, ('series_' + key2).replace(".cache", ""), data[key][key2].join("\n"));
			}
			table_counter++;
		}
		jQuery('#results').append(rowstxt);
		alignRight();

		var d = new Date();
		var h = (data.length - howmany);
		jQuery('#message').html("(updated on " + d.toISOString() + " - " + h + (h != 1 ? " new entries)" : " new entry)"));
		//addThumbnails();
		if (!stopQuery) {
			setTimeout(checkQueryID, 2000);
		} else {
			// if we don't have data alert
			if (data.length == 0) {
				alert("No data could be copied from PACS.");
			}
			jQuery('div.progress').hide();
			addThumbnails();
		}
	}).fail(function(xhr, error, StatusMessage) {
		console.log("query failed.. no JSON produced...");
		// maybe it failed only once?
		setTimeout(checkQueryID, 2000);
	});
}

var stopQuery = false;
var counter = 0;
var startDateTime; // for tracking of time required to finish
function checkFinished() {
	jQuery.getJSON('php/data/' + lastQueryID + '/info.json', function(data) {
		if (typeof data['enddate'] != 'undefined') {
			jQuery('#finished').addClass('finished');
			stopQuery = true;
			jQuery('#message-text').text();
			//jQuery('div.progress').hide();
			return;
		} else {
			jQuery('#finished').removeClass('finished');
		}
		// update the progress bar length and message
		if (typeof data['num_participant'] != 'undefined' && typeof data['total_num_participants'] != 'undefined') {
			var t = Math.floor((data['num_participant'] / data['total_num_participants']) * 100);
			jQuery('#finished').attr('aria-valuenow', t);
			jQuery('#finished').css('width', t + "%");
			var now = moment();
			// running now
			var timespend = moment.duration(now.diff(startDateTime)).asSeconds(); // per t so far
			// timespend/data['num_participant'] = ?/(data['total_num_participants'] - data['num_participant'])
			var timeexpected = timespend / data['num_participant'] * (data['total_num_participants'] - data['num_participant']);
			jQuery('#progress-message').text("processing running now for " + moment.duration(now.diff(startDateTime)).humanize() + ", will be done in " + moment.duration(timeexpected, 'seconds').humanize());

			counter++;
			var dots = ".";
			for (var i = 0; i < counter % 3; i++) {
				dots += ".";
			}

			jQuery('#message-text').text("Scan for tags" + dots + " (" + data['num_participant'] + " of " + data['total_num_participants'] + " DICOM studies)");
		}
		setTimeout(checkFinished, 6000);
	});
}

function alignRight() {
	jQuery('#content div.Study').each(function(idx, value) {
		// console.log("we have row number: " + (idx % 3));
		var height = jQuery(value).css('height');
		var id = jQuery(value).attr('id');
		var height2 = jQuery('#' + id.replace(/\./g, "\\.") + '-s').css('height');
		//if (parseInt(height) < parseInt(height2)) {
		//    height = height2;
		//}
		jQuery('#' + id.replace(/\./g, "\\.") + '-s').css('height', height);
	});
	// we should also sort the series by SeriesNumber - but this inserts them twice with the same ID
	/*jQuery('#content div.Study').each(function(idx, value) {
	jQuery(value).find('div.Series').sort(function(a,b) {
	    return jQuery(a).find("div.SeriesNumber").text() - jQuery(b).find("div.SeriesNumber").text();
	}).appendTo(value);
    }); */
}

var lastQueryID = "";
var dicom_dict = {};
jQuery(document).ready(function() {

    jQuery('#handle-name').on('change', function() {
	var name = jQuery('#handle-name').val();
	try {
	    localStorage.setItem('handle-name', JSON.stringify(name));
	} catch(e) {
	    console.log("Warning: no localStorage");
	}
    });
    // if the name exists we pull and fill
    try {
	var handle = localStorage.getItem("handle-name");
	if (handle !== null) {
	    jQuery('#handle-name').val(JSON.parse(handle));
	}
    } catch(e) {
	console.log("Warning: no localStorage");
    }    
    
    jQuery('#share-world-button').on('click', function() {
	var handle = jQuery('#handle-name').val();
	var name = jQuery('#BP_search_box').val();
	var models = jQuery('#share-world-button').attr('model-names');
	if (name == "") {
	    console.log("Info: a name for the export is not required, nor a handle");
	}
	jQuery.getJSON('/php/shareModel.php', { name: name, handle: handle, models: models }, function(data) {
	    console.log("got back: " + JSON.stringify(data));
	});
    });

        jQuery('#processing-time').on('click', function() {
		// display the decision tree as a graphic
		jQuery('#tree-modal').modal('show');
	});

	jQuery('#full-export').on('click', function() {
		var name = jQuery('#export-name').val();
		if (name.length == 0) {
			name = "selection";
		}

		var to_export = {};
		jQuery('#content-selected').find('div.Series').each(function(i, a) {
			var SeriesInstanceUID = jQuery(a).attr('id').replace("-s", "").replace("series_", "");
			var StudyInstanceUID = jQuery(a).parent().attr('id').replace("-s", "").replace("study_", "");
			if (typeof to_export[StudyInstanceUID] === 'undefined')
				to_export[StudyInstanceUID] = [];
			to_export[StudyInstanceUID].push(SeriesInstanceUID);
		});
		jQuery.post('php/exportAsFolders.php', {
			name: name,
			id: lastQueryID,
			to_export: JSON.stringify(to_export)
		}, function(data) {
			// should be in the background.. may take a long time
			console.log("ok, is running now");
			alert(data['message']);
		}, 'json');
	});

	jQuery('.download-selected').on('click', function() {
		// download a spreadsheet with the series instance uid's from research PACS
		var content = "SeriesInstanceUID,StudyInstanceUID\n";
		jQuery('#content-selected').find('div.Series').each(function(i, a) {
			var SeriesInstanceUID = jQuery(a).attr('id').replace("-s", "").replace("series_", "");
			var StudyInstanceUID = jQuery(a).parent().attr('id').replace("-s", "").replace("study_", "");
			content = content + SeriesInstanceUID + "," + StudyInstanceUID + "\n";
		});

		var name = jQuery('#export-name').val();
		if (name.length == 0) {
			name = "selection";
		}
		var csv = "data:text/csv;charset=utf-8," + content;
		var encodeUri = encodeURI(csv);
		var link = document.createElement("a");
		link.setAttribute("href", encodeUri);
		link.setAttribute("download", name + ".csv");
		document.body.appendChild(link);
		link.click();
	});

	// get the DICOM dictionary
	jQuery.getJSON('js/StandardDICOMElements.json', function(data) {
		dicom_dict = data;
	});

	jQuery(window).resize(function() {
		alignRight();
	});

	if (typeof calledQueryID != 'undefined') {
		lastQueryID = calledQueryID;
		setTimeout(function() {
			setTimeout(checkQueryID, 2000);
			setTimeout(checkFinished, 10000);
		}, 10);
	}

	populateStudyInstanceUIDs();
	jQuery('#project').on('change', function() {
		console.log("change project to " + jQuery(this).val());
		jQuery('#model_nav').children().remove();
		jQuery('#finished').removeClass('finished');
		jQuery('#chat').val("");
		jQuery('#message-text').text("");
		jQuery('#processing-time').text("");
		jQuery('span.stats').text("");
		jQuery('span.stats-general').text("");

		// remember when this was
		startDateTime = moment();

		var project = jQuery(this).val();
		var allowCache = "0";
		if (jQuery('#allowCachedVersion').is(':checked'))
			allowCache = "1";
		jQuery.getJSON('php/pullTags.php', {
			'project': project,
			'allowCache': allowCache
		}, function(data) {
			lastQueryID = data.ID;
			stopQuery = false;
			setTimeout(checkQueryID, 2000);
			setTimeout(checkFinished, 10000);
		});
	});

	// for touch devices we do a touch for click and a taphold for shift-click (right mouse)
	jQuery('#content').on('touch', 'div.Series', function(e) {
		jQuery(this).trigger('click');
	});

	jQuery('#content').on('taphold', 'div.Series', function(e) {
		var shiftClick = jQuery.Event('click');
		shiftClick.shiftKey = true;
		jQuery(this).trigger(shiftClick);
	});

	jQuery('#content').on('click', 'div.Series', function(e) {
		// console.log(jQuery(this).attr('data'));
		var studyinstanceuid = jQuery(this).parent().attr('id');
		var seriesinstanceuid = jQuery(this).attr('id');
		var ar = dataCache[studyinstanceuid][seriesinstanceuid]; // parseDICOMStruct(jQuery(this).attr('data'));
		// we have now a group, tag structure with values
		console.log(JSON.stringify(ar));
		// highlight this image
		if (jQuery(this).hasClass('highlighted-human-a') || jQuery(this).hasClass('highlighted-human-b')) {
			jQuery(this).removeClass('highlighted-human-a');
			jQuery(this).removeClass('highlighted-human-b');
		} else {
			if (e.shiftKey) {
				jQuery(this).addClass('highlighted-human-b');
			} else {
				jQuery(this).addClass('highlighted-human-a');
			}
		}

		// get a classification based on the selected subsets
		sendToClassifier();
	});
});
