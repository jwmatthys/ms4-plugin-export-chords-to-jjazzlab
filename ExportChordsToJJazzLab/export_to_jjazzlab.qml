import MuseScore
import QtQuick
import FileIO

MuseScore {
    id: plugin
    menuPath: "Export Chords to Textfile"
    description: "Export chord symbols from selection to grid-based text format compatible with JJazzLab or ChordPulse."
    categoryCode: "Export"
    version: "1.0"
    thumbnailName: "export_to_jjazzlab.png"
    requiresScore: true

    property var chordData: []
    property var barlineTicks: []
    
    FileIO {
        id: outputFile
        source: ""
    }

    function getTimeSigString(measure) {
        var ts = measure.timesigActual
        if (ts) {
            return ts.numerator + "/" + ts.denominator
        }
        return "4/4"
    }
    
    function isChordSymbol(element) {
        if (element.harmonyType !== undefined && element.harmonyType !== 0) {
            return false
        }
        return true
    }

    function collectData() {
        chordData = []
        barlineTicks = []
        
        // Select all if nothing selected
        if (curScore.selection.elements.length === 0) {
            cmd("select-all")
        }
        
        var startTick = 0
        var endTick = curScore.lastSegment.tick
        
        var selection = curScore.selection
        if (selection && selection.startSegment && selection.endSegment) {
            startTick = selection.startSegment.tick
            endTick = selection.endSegment.tick
        }
        
        var segment = curScore.firstSegment()
        var firstTimeSig = "4/4"
        var gotFirstTimeSig = false
        
        while (segment) {
            var tick = segment.tick
            
            if (tick > endTick) break
            
            if (!gotFirstTimeSig && segment.parent && segment.parent.type === Element.MEASURE) {
                firstTimeSig = getTimeSigString(segment.parent)
                gotFirstTimeSig = true
            }
            
            for (var track = 0; track < curScore.ntracks; track++) {
                var element = segment.elementAt(track)
                if (element && element.type === Element.BAR_LINE) {
                    if (barlineTicks.indexOf(tick) === -1) {
                        barlineTicks.push(tick)
                    }
                    break
                }
            }
            
            if (tick >= startTick) {
                var annotations = segment.annotations
                if (annotations) {
                    for (var i = 0; i < annotations.length; i++) {
                        var ann = annotations[i]
                        if (ann.type === Element.HARMONY) {
                            if (isChordSymbol(ann)) {
                                var name = ann.text
                                if (name && name.length > 0) {
                                    var timeSig = "4/4"
                                    if (segment.parent && segment.parent.type === Element.MEASURE) {
                                        timeSig = getTimeSigString(segment.parent)
                                    }
                                    chordData.push({
                                        tick: tick,
                                        name: name,
                                        timeSig: timeSig
                                    })
                                }
                            }
                        }
                    }
                }
            }
            
            segment = segment.next
        }
        
        barlineTicks.sort(function(a, b) { return a - b })
        chordData.sort(function(a, b) { return a.tick - b.tick })
    }

    function getMeasureIndex(tick) {
        for (var i = 0; i < barlineTicks.length; i++) {
            if (tick < barlineTicks[i]) {
                return i
            }
        }
        return barlineTicks.length
    }

    function generateChordChart() {
        if (chordData.length === 0) {
            return "No chord symbols found in selection."
        }
        
        var result = ""
        var measuresPerLine = 4
        var lastTimeSig = ""
        var lastMeasureContent = ""
        var measuresOnLine = 0
        var lineContent = ""
        
        var measureMap = {}
        var measureTimeSigs = {}
        var maxMeasure = 0
        var minMeasure = 999999
        
        for (var i = 0; i < chordData.length; i++) {
            var chord = chordData[i]
            var measureIdx = getMeasureIndex(chord.tick)
            
            if (!measureMap[measureIdx]) {
                measureMap[measureIdx] = []
            }
            measureMap[measureIdx].push(chord)
            measureTimeSigs[measureIdx] = chord.timeSig
            
            if (measureIdx > maxMeasure) maxMeasure = measureIdx
            if (measureIdx < minMeasure) minMeasure = measureIdx
        }
        
        for (var m = minMeasure; m <= maxMeasure; m++) {
            var measureContent = ""
            var timeSigStr = measureTimeSigs[m] || lastTimeSig
            
            var showTimeSig = (timeSigStr !== lastTimeSig && timeSigStr !== "")
            if (showTimeSig) {
                measureContent = timeSigStr + " "
                lastTimeSig = timeSigStr
            }
            
            var chords = measureMap[m]
            if (chords && chords.length > 0) {
                chords.sort(function(a, b) { return a.tick - b.tick })
                
                var chordNames = []
                for (var j = 0; j < chords.length; j++) {
                    chordNames.push(chords[j].name)
                }
                measureContent += chordNames.join(" ")
            }
            
            var finalContent = measureContent.trim()
            
            if (finalContent === lastMeasureContent && finalContent !== "" && !showTimeSig) {
                finalContent = "%"
            } else if (finalContent !== "") {
                lastMeasureContent = finalContent
            }
            
            while (finalContent.length < 7) {
                finalContent += " "
            }
            
            lineContent += "| " + finalContent + " "
            measuresOnLine++
            
            if (measuresOnLine >= measuresPerLine) {
                lineContent += "|"
                result += lineContent + "\n"
                lineContent = ""
                measuresOnLine = 0
            }
        }
        
        if (lineContent !== "") {
            lineContent += "|"
            result += lineContent
        }
        
        return result.trim()
    }
    
    function getOutputPath() {
        var scoreName = curScore.scoreName || "chords"
        var lastDot = scoreName.lastIndexOf(".")
        if (lastDot > 0) {
            scoreName = scoreName.substring(0, lastDot)
        }
        return outputFile.homePath() + "/Documents/" + scoreName + "_chords.txt"
    }

    onRun: {
        if (!curScore) {
            quit()
            return
        }
        
        collectData()
        
        if (chordData.length === 0) {
            quit()
            return
        }
        
        var result = generateChordChart()
        var outputPath = getOutputPath()
        
        outputFile.source = outputPath
        outputFile.write(result)
        
        quit()
    }
}