# BehaviourPresets.gd
extends Node

const MASKS := {
	"default": {
		"alignment": true,
		"cohesion": true,
		"separation": true,
		"wander": true,
		"boundary": true
	},

	"no_alignment": {
		"alignment": false,
		"cohesion": true,
		"separation": true,
		"wander": true,
		"boundary": true
	},

	"pure_separation": {
		"alignment": false,
		"cohesion": false,
		"separation": true,
		"wander": false,
		"boundary": false
	},

	"ballistic": {
		"alignment": false,
		"cohesion": false,
		"separation": false,
		"wander": false,
		"boundary": false
	}
}
